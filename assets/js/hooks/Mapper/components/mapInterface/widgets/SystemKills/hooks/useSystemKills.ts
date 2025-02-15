import { useCallback, useMemo, useState, useEffect, useRef } from 'react';
import debounce from 'lodash.debounce';
import { Commands, OutCommand } from '@/hooks/Mapper/types/mapHandlers';
import { DetailedKill } from '@/hooks/Mapper/types/kills';
import { useMapRootState } from '@/hooks/Mapper/mapRootProvider';
import { useKillsWidgetSettings } from './useKillsWidgetSettings';
import { useMapEventListener, MapEvent } from '@/hooks/Mapper/events';

interface UseSystemKillsProps {
  systemId?: string;
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  outCommand: (payload: any) => Promise<any>;
  showAllVisible?: boolean;
  sinceHours?: number;
}

function combineKills(
  existing: DetailedKill[],
  incoming: DetailedKill[],
  sinceHours: number
): DetailedKill[] {
  const cutoff = Date.now() - sinceHours * 60 * 60 * 1000;
  const byId: Record<string, DetailedKill> = {};

  for (const kill of [...existing, ...incoming]) {
    if (!kill.kill_time) continue;
    const killTimeMs = new Date(kill.kill_time).valueOf();
    if (killTimeMs >= cutoff) {
      byId[kill.killmail_id] = kill;
    }
  }

  return Object.values(byId);
}

interface DetailedKillsEvent extends MapEvent<Commands> {
  payload: Record<string, DetailedKill[]>;
}

export function useSystemKills({
  systemId,
  outCommand,
  showAllVisible = false,
  sinceHours = 24,
}: UseSystemKillsProps) {
  const { data, update } = useMapRootState();
  const { detailedKills = {}, systems = [] } = data;
  const [settings] = useKillsWidgetSettings();
  const excludedSystems = settings.excludedSystems;

  const updateDetailedKills = useCallback((newKillsMap: Record<string, DetailedKill[]>) => {
    update((prev) => {
      const oldKills = prev.detailedKills ?? {};
      const updated = { ...oldKills };
      for (const [sid, killsArr] of Object.entries(newKillsMap)) {
        updated[sid] = killsArr;
      }
      return { ...prev, detailedKills: updated };
    }, true);
  }, [update]);

  useMapEventListener((event: MapEvent<Commands>) => {
    if (event.name === Commands.detailedKillsUpdated) {
      const detailedEvent = event as DetailedKillsEvent;
      if (systemId && !Object.keys(detailedEvent.payload).includes(systemId.toString())) {
        return false;
      }
      updateDetailedKills(detailedEvent.payload);
      return true;
    }
    return false;
  });

  const effectiveSystemIds = useMemo(() => {
    if (showAllVisible) {
      return systems.map((s) => s.id).filter((id) => !excludedSystems.includes(Number(id)));
    }
    return systems.map((s) => s.id);
  }, [systems, excludedSystems, showAllVisible]);

  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const didFallbackFetch = useRef(Object.keys(detailedKills).length !== 0);

  const mergeKillsIntoGlobal = useCallback((killsMap: Record<string, DetailedKill[]>) => {
    update((prev) => {
      const oldMap = prev.detailedKills ?? {};
      const updated: Record<string, DetailedKill[]> = { ...oldMap };

      for (const [sid, newKills] of Object.entries(killsMap)) {
        const existing = updated[sid] ?? [];
        const combined = combineKills(existing, newKills, sinceHours);
        updated[sid] = combined;
      }

      return { ...prev, detailedKills: updated };
    });
  }, [update, sinceHours]);

  const fetchKills = useCallback(async (forceFallback = false) => {
    setIsLoading(true);
    setError(null);

    try {
      let eventType: OutCommand;
      let requestData: Record<string, unknown>;

      if (showAllVisible || forceFallback) {
        eventType = OutCommand.getSystemsKills;
        requestData = {
          system_ids: effectiveSystemIds,
          since_hours: sinceHours,
        };
      } else if (systemId) {
        eventType = OutCommand.getSystemKills;
        requestData = {
          system_id: systemId,
          since_hours: sinceHours,
        };
      } else {
        setIsLoading(false);
        return;
      }

      const resp = await outCommand({
        type: eventType,
        data: requestData,
      });

      if (resp?.kills) {
        const arr = resp.kills as DetailedKill[];
        const sid = systemId ?? 'unknown';
        mergeKillsIntoGlobal({ [sid]: arr });
      }
      else if (resp?.systems_kills) {
        mergeKillsIntoGlobal(resp.systems_kills as Record<string, DetailedKill[]>);
      } else {
        console.warn('[useSystemKills] Unexpected kills response =>', resp);
      }
    } catch (err) {
      console.error('[useSystemKills] Failed to fetch kills:', err);
      setError(err instanceof Error ? err.message : 'Error fetching kills');
    } finally {
      setIsLoading(false);
    }
  }, [showAllVisible, systemId, outCommand, effectiveSystemIds, sinceHours, mergeKillsIntoGlobal]);

  const debouncedFetchKills = useMemo(
    () =>
      debounce(fetchKills, 500, {
        leading: true,
        trailing: false,
      }),
    [fetchKills],
  );

  const finalKills = useMemo(() => {
    if (showAllVisible) {
      return effectiveSystemIds.flatMap((sid) => detailedKills[sid] ?? []);
    } else if (systemId) {
      return detailedKills[systemId] ?? [];
    } else if (didFallbackFetch.current) {
      return effectiveSystemIds.flatMap((sid) => detailedKills[sid] ?? []);
    }
    return [];
  }, [showAllVisible, systemId, effectiveSystemIds, detailedKills]);

  const effectiveIsLoading = isLoading && finalKills.length === 0;

  useEffect(() => {
    if (!systemId && !showAllVisible && !didFallbackFetch.current) {
      didFallbackFetch.current = true;
      debouncedFetchKills.cancel();
      fetchKills(true); 
    }
  }, [systemId, showAllVisible, debouncedFetchKills, fetchKills]);

  useEffect(() => {
    if (effectiveSystemIds.length === 0) return;

    if (showAllVisible || systemId) {
      debouncedFetchKills();
      return () => debouncedFetchKills.cancel();
    }
  }, [showAllVisible, systemId, effectiveSystemIds, debouncedFetchKills]);

  const refetch = useCallback(() => {
    debouncedFetchKills.cancel();
    fetchKills();
  }, [debouncedFetchKills, fetchKills]);

  return {
    kills: finalKills,
    isLoading: effectiveIsLoading,
    error,
    refetch,
  };
}
