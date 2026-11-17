import type { ToastMessage } from 'primereact/toast';
import { Toast } from 'primereact/toast';
import { useCallback, useEffect, useRef } from 'react';

import { MapEvent, useMapEventListener } from '@/hooks/Mapper/events';
import { useAudioPlayer } from '@/hooks/Mapper/hooks';
import { useMapRootState } from '@/hooks/Mapper/mapRootProvider';
import { normalizeKillNotificationToastLifetime } from '@/hooks/Mapper/mapRootProvider/helpers/normalizeKillNotificationToastLifetime.ts';
import { PingsPlacement } from '@/hooks/Mapper/mapRootProvider/types.ts';
import { Command, Commands } from '@/hooks/Mapper/types';
import { DetailedKill } from '@/hooks/Mapper/types/kills.ts';
import { KillNotificationContent } from './KillNotificationContent.tsx';
import {
  findKillSystem,
  getKillTimestamp,
  isRecentKill,
  isSystemIncluded,
  PendingKillNotification,
} from './helpers.ts';

const KILL_SOUND_PATH = '/sounds/lil-pip.wav';
const KILL_AUDIO_OPTIONS = { volume: 0.4 } as const;
const KILL_TOAST_ORDER_EPOCH_MS = Date.UTC(2020, 0, 1);

export const useMapKillsNotifications = () => {
  const {
    storedSettings: { interfaceSettings },
    data: { detailedKills, pings, systems },
  } = useMapRootState();

  const toastRef = useRef<Toast>(null);
  const seenKillmailIdsRef = useRef(new Set<number>());
  const hasReceivedInitialUpdateRef = useRef(false);
  const playKillSound = useAudioPlayer(KILL_SOUND_PATH, KILL_AUDIO_OPTIONS);

  const showNotifications = useCallback((notifications: PendingKillNotification[], toastLifetimeSeconds: number) => {
    const messages: ToastMessage[] = notifications.map(({ kill, system, timestamp }) => {
      const message: ToastMessage = {
        id: kill.killmail_id.toString(),
        severity: 'warn',
        className: 'kill-activity-toast',
        content: <KillNotificationContent kill={kill} systemId={system.id} />,
        style: { order: -Math.floor((timestamp - KILL_TOAST_ORDER_EPOCH_MS) / 1_000) },
      };

      if (toastLifetimeSeconds <= 0) {
        return { ...message, sticky: true };
      }

      return { ...message, life: toastLifetimeSeconds * 1_000 };
    });

    toastRef.current?.show(messages);
  }, []);

  useEffect(() => {
    Object.values(detailedKills).forEach(kills => {
      kills.forEach(kill => seenKillmailIdsRef.current.add(kill.killmail_id));
    });
  }, [detailedKills]);

  const handleDetailedKillsUpdated = useCallback(
    (event: MapEvent<Command>) => {
      if (event.name !== Commands.detailedKillsUpdated) {
        return false;
      }

      let hasNewKills = false;
      const killsBySystem = event.data as Record<string, DetailedKill[]>;

      if (!hasReceivedInitialUpdateRef.current) {
        Object.values(killsBySystem).forEach(kills => {
          kills.forEach(kill => seenKillmailIdsRef.current.add(kill.killmail_id));
        });
        hasReceivedInitialUpdateRef.current = true;
        return true;
      }

      const toastLifetimeSeconds = normalizeKillNotificationToastLifetime(
        interfaceSettings.killActivityToastLifetimeSeconds,
      );
      const notifications: PendingKillNotification[] = [];

      Object.entries(killsBySystem).forEach(([systemId, kills]) => {
        const system = findKillSystem(systems, systemId);

        kills.forEach(kill => {
          const isSeen = seenKillmailIdsRef.current.has(kill.killmail_id);
          seenKillmailIdsRef.current.add(kill.killmail_id);
          const timestamp = getKillTimestamp(kill);

          if (
            isSeen ||
            timestamp === null ||
            !isRecentKill(timestamp) ||
            !system ||
            !isSystemIncluded(system, kill.solar_system_id, interfaceSettings)
          ) {
            return;
          }

          hasNewKills = true;

          if (interfaceSettings.killActivityNotifications) {
            notifications.push({ kill, system, timestamp });
          }
        });
      });

      if (notifications.length > 0) {
        showNotifications(notifications, toastLifetimeSeconds);
      }

      if (hasNewKills && interfaceSettings.killActivitySounds) {
        playKillSound().catch(error => console.warn('Could not play kill sound:', error));
      }

      return true;
    },
    [interfaceSettings, playKillSound, showNotifications, systems],
  );

  useMapEventListener(handleDetailedKillsUpdated);

  return {
    toastRef,
    hasPing: pings.length === 1,
    isShowMenu: interfaceSettings.isShowMenu,
    pingsPlacement: interfaceSettings.pingsPlacement ?? PingsPlacement.rightTop,
  };
};
