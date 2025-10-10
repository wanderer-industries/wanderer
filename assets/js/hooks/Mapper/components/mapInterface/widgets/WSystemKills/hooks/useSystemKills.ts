import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { OutCommand } from '@/hooks/Mapper/types/mapHandlers';
import { DetailedKill } from '@/hooks/Mapper/types/kills';
import { useMapRootState } from '@/hooks/Mapper/mapRootProvider';
import { useStableValue } from '@/hooks/Mapper/hooks';

interface UseSystemKillsProps {
  systemId?: string;
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  outCommand: (payload: any) => Promise<any>;
  showAllVisible?: boolean;
  sinceHours?: number;
}

function combineKills(existing: DetailedKill[], incoming: DetailedKill[]): DetailedKill[] {
  // Don't filter by time when storing - let components filter when displaying
  const byId: Record<string, DetailedKill> = {};

  for (const kill of [...existing, ...incoming]) {
    if (!kill.kill_time) continue;
    byId[kill.killmail_id] = kill;
  }

  return Object.values(byId);
}

export function useSystemKills({ systemId, outCommand, showAllVisible = false, sinceHours = 24 }: UseSystemKillsProps) {
  const {
    data: { detailedKills = {}, systems = [] },
    update,
    storedSettings: { settingsKills },
  } = useMapRootState();

  const excludedSystems = useStableValue(settingsKills.excludedSystems);

  const effectiveSystemIds = useMemo(() => {
    if (showAllVisible) {
      return systems.map(s => s.id).filter(id => !excludedSystems.includes(Number(id)));
    }
    return systems.map(s => s.id);
  }, [systems, excludedSystems, showAllVisible]);

  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const didFallbackFetch = useRef(Object.keys(detailedKills).length !== 0);

  const mergeKillsIntoGlobal = useCallback(
    (killsMap: Record<string, DetailedKill[]>) => {
      update(prev => {
        const oldMap = prev.detailedKills ?? {};
        const updated: Record<string, DetailedKill[]> = { ...oldMap };

        for (const [sid, newKills] of Object.entries(killsMap)) {
          const existing = updated[sid] ?? [];
          const combined = combineKills(existing, newKills);
          updated[sid] = combined;
        }

        return { ...prev, detailedKills: updated };
      });
    },
    [update],
  );

  const fetchKills = useCallback(
    async (forceFallback = false) => {
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
        } else if (resp?.systems_kills) {
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
    },
    [showAllVisible, systemId, outCommand, effectiveSystemIds, sinceHours, mergeKillsIntoGlobal],
  );

  const finalKills = useMemo(() => {
    let result: DetailedKill[] = [];

    if (showAllVisible) {
      result = effectiveSystemIds.flatMap(sid => detailedKills[sid] ?? []);
    } else if (systemId) {
      result = detailedKills[systemId] ?? [];
    } else if (didFallbackFetch.current) {
      result = effectiveSystemIds.flatMap(sid => detailedKills[sid] ?? []);
    }

    return result;
  }, [showAllVisible, systemId, effectiveSystemIds, detailedKills, didFallbackFetch]);

  const effectiveIsLoading = isLoading && finalKills.length === 0;

  useEffect(() => {
    if (!systemId && !showAllVisible && !didFallbackFetch.current) {
      didFallbackFetch.current = true;
      fetchKills(true);
    }
  }, [systemId, showAllVisible, fetchKills]);

  useEffect(() => {
    if (effectiveSystemIds.length === 0) return;

    if (showAllVisible || systemId) {
      fetchKills();
      return;
    }
  }, [showAllVisible, systemId, effectiveSystemIds, fetchKills]);

  const refetch = useCallback(() => {
    fetchKills();
  }, [fetchKills]);

  return {
    kills: finalKills,
    isLoading: effectiveIsLoading,
    error,
    refetch,
  };
}
