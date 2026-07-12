import React, { useCallback, useRef } from 'react';
import { useMapEventListener } from '@/hooks/Mapper/events';
import { Commands } from '@/hooks/Mapper/types';
import { useMapRootState } from '@/hooks/Mapper/mapRootProvider';
import { Toast } from 'primereact/toast';
import { DetailedKill } from '@/hooks/Mapper/types/kills';
import { getSystemStaticInfo } from '@/hooks/Mapper/mapRootProvider/hooks/useLoadSystemStatic';

interface DetailedKillsEvent {
  name: Commands;
  data?: Record<string, DetailedKill[]>;
}

export const MapKillsNotifications = () => {
  const { storedSettings, data: rootData } = useMapRootState();
  const { interfaceSettings } = storedSettings;
  const { systems } = rootData;
  
  const toastRef = useRef<Toast>(null);
  const audioRef = useRef<HTMLAudioElement>(null);
  
  // Track which killmail IDs we've already notified about
  const seenKillmailIdsRef = useRef<Set<number>>(new Set());
  // Track whether initial load has completed (to avoid spamming on first historical fetch)
  const initialLoadCompleteRef = useRef(false);

  const handleEvent = useCallback((event: DetailedKillsEvent) => {
    if (event.name !== Commands.detailedKillsUpdated || !event.data) return false;

    // Wait until initial systems are loaded
    if (!systems || systems.length === 0) return false;

    // On the very first detailedKillsUpdated event, just record IDs without notifying
    // This prevents spamming notifications for all historical kills on page load
    if (!initialLoadCompleteRef.current) {
      initialLoadCompleteRef.current = true;
      for (const [, kills] of Object.entries(event.data)) {
        for (const kill of kills) {
          if (kill.killmail_id) {
            seenKillmailIdsRef.current.add(kill.killmail_id);
          }
        }
      }
      return true;
    }

    let shouldPlaySound = false;

    for (const [systemId, kills] of Object.entries(event.data)) {
      // Check if this system is on our map
      const systemOnMap = systems.find(
        s => s.id === systemId || s.system_static_info?.solar_system_id?.toString() === systemId
      );
      if (!systemOnMap) continue;

      // Find new kills we haven't seen before
      const newKills = kills.filter(k => {
        if (!k.killmail_id || seenKillmailIdsRef.current.has(k.killmail_id)) {
          return false;
        }
        if (k.kill_time) {
          const killTime = new Date(k.kill_time).getTime();
          const now = Date.now();
          if (now - killTime > 15 * 60 * 1000) {
            return false;
          }
        }
        
        return true;
      });
      
      // Record all IDs as seen
      for (const kill of kills) {
        if (kill.killmail_id) {
          seenKillmailIdsRef.current.add(kill.killmail_id);
        }
      }

      if (newKills.length === 0) continue;

      // Show notification for each new kill
      if (interfaceSettings.killActivityNotifications) {
        const staticInfo = systemOnMap.system_static_info || getSystemStaticInfo(systemId);
        const staticName = staticInfo?.solar_system_name || 'Unknown System';
        const tempName = systemOnMap.temporary_name || systemOnMap.name;
        const systemName = tempName && tempName !== staticName ? `${tempName} (${staticName})` : staticName;
        
        for (const kill of newKills) {
          const victimName = kill.victim_char_name || 'Unknown Pilot';
          const shipName = kill.victim_ship_name || 'Unknown Ship';
          
          toastRef.current?.show({
            severity: 'warn',
            summary: `Kill in ${systemName}`,
            detail: `${victimName} lost a ${shipName}`,
            life: 30000,
            closable: true,
          });
        }
      }

      if (interfaceSettings.killActivitySounds) {
        shouldPlaySound = true;
      }
    }

    if (shouldPlaySound && audioRef.current) {
      audioRef.current.currentTime = 0;
      audioRef.current.volume = (interfaceSettings.killActivitySoundVolume ?? 50) / 100;
      audioRef.current.play().catch(e => console.warn('Could not play kill sound:', e));
    }

    return true;
  }, [systems, interfaceSettings.killActivityNotifications, interfaceSettings.killActivitySounds, interfaceSettings.killActivitySoundVolume, interfaceSettings.killActivitySoundFile]);

  useMapEventListener(handleEvent);

  return (
    <>
      <Toast ref={toastRef} position="bottom-right" />
      <audio ref={audioRef} src={`/sounds/${interfaceSettings.killActivitySoundFile || 'xbox.mp3'}`} preload="auto" />
    </>
  );
};
