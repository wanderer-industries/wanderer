import { useCallback, useMemo, useState, useEffect, useRef } from 'react';
import debounce from 'lodash.debounce';
import { OutCommand } from '@/hooks/Mapper/types/mapHandlers';
import { DetailedKill } from '@/hooks/Mapper/types/kills';
import { useMapRootState } from '@/hooks/Mapper/mapRootProvider';

interface UseSystemKillsProps {
  systemId?: string;
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  outCommand: (payload: any) => Promise<any>;
  showAllVisible: boolean;
  sinceHours?: number;
  timeoutMs?: number;
}

function withTimeout<T>(promise: Promise<T>, ms?: number): Promise<T> {
  if (!ms) return promise;
  return new Promise((resolve, reject) => {
    const timer = setTimeout(() => {
      reject(new Error(`Request timed out after ${ms} ms.`));
    }, ms);

    promise
      .then(value => {
        clearTimeout(timer);
        resolve(value);
      })
      .catch(err => {
        clearTimeout(timer);
        reject(err);
      });
  });
}

export function useSystemKills({
  systemId,
  outCommand,
  showAllVisible,
  sinceHours = 24,
  timeoutMs = 500,
}: UseSystemKillsProps) {
  const { data, update } = useMapRootState();
  const { detailedKills = {}, systems = [] } = data;

  const visibleSystemIds = useMemo(() => systems.map(s => s.id), [systems]);

  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const didFallbackFetch = useRef(false);

  const mergeKillsIntoGlobal = useCallback(
    (killsMap: Record<string, DetailedKill[]>) => {
      update(prev => {
        const oldMap = prev.detailedKills ?? {};
        const updated: Record<string, DetailedKill[]> = { ...oldMap };

        for (const [sid, newKills] of Object.entries(killsMap)) {
          const existing = updated[sid] ?? [];
          updated[sid] = [...existing, ...newKills];
        }
        return { ...prev, detailedKills: updated };
      });
    },
    [update],
  );

  const fetchKills = useCallback(async () => {
    if (visibleSystemIds.length === 0) return;

    setIsLoading(true);
    setError(null);

    try {
      let eventType: OutCommand;
      let requestData: Record<string, unknown>;

      if (showAllVisible) {
        eventType = OutCommand.getSystemsKills;
        requestData = {
          system_ids: visibleSystemIds,
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

      const resp = await withTimeout(outCommand({ type: eventType, data: requestData }), timeoutMs);

      if (resp.kills) {
        const arr = resp.kills as DetailedKill[];
        const sid = systemId ?? 'unknown';
        mergeKillsIntoGlobal({ [sid]: arr });
      } else if (resp.systems_kills) {
        mergeKillsIntoGlobal(resp.systems_kills as Record<string, DetailedKill[]>);
      } else {
        console.warn('Unexpected kills response =>', resp);
      }
    } catch (err) {
      console.error('[useSystemKills] Failed to fetch kills:', err);
      setError(err instanceof Error ? err.message : 'Error fetching kills');
    } finally {
      setIsLoading(false);
    }
  }, [systemId, showAllVisible, sinceHours, visibleSystemIds, timeoutMs, outCommand, mergeKillsIntoGlobal]);

  const fallbackFetch = useCallback(async () => {
    if (didFallbackFetch.current) return;
    if (systemId || showAllVisible) return;

    didFallbackFetch.current = true;

    try {
      const resp = await withTimeout(
        outCommand({
          type: OutCommand.getSystemsKills,
          data: {
            system_ids: visibleSystemIds,
            since_hours: sinceHours,
          },
        }),
        timeoutMs,
      );

      if (resp.systems_kills) {
        mergeKillsIntoGlobal(resp.systems_kills as Record<string, DetailedKill[]>);
      } else if (resp.kills) {
        const arr = resp.kills as DetailedKill[];
        mergeKillsIntoGlobal({ __fallbackAll__: arr });
      }
    } catch (err) {
      console.error('[useSystemKills][fallbackFetch] error:', err);
    }
  }, [systemId, showAllVisible, sinceHours, visibleSystemIds, timeoutMs, outCommand, mergeKillsIntoGlobal]);

  const debouncedFetchKills = useMemo(() => debounce(fetchKills, 500), [fetchKills]);

  useEffect(() => {
    debouncedFetchKills();
    return () => debouncedFetchKills.cancel();
  }, [debouncedFetchKills]);

  useEffect(() => {
    fallbackFetch();
  }, [fallbackFetch]);

  const finalKills = useMemo(() => {
    if (showAllVisible || didFallbackFetch.current) {
      return visibleSystemIds.flatMap(sid => detailedKills[sid] ?? []);
    }
    if (systemId) {
      return detailedKills[systemId] ?? [];
    }
    return [];
  }, [showAllVisible, systemId, visibleSystemIds, detailedKills]);

  const effectiveIsLoading = isLoading && finalKills.length === 0;

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
