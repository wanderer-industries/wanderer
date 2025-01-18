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

function withTimeout<T>(promise: Promise<T>, ms: number): Promise<T> {
  if (!ms) return promise;
  return new Promise((resolve, reject) => {
    const timer = setTimeout(() => {
      reject(new Error(`Request timed out after ${ms} ms`));
    }, ms);

    promise
      .then(val => {
        clearTimeout(timer);
        resolve(val);
      })
      .catch(err => {
        clearTimeout(timer);
        reject(err);
      });
  });
}

function scheduleIdleCallback(cb: () => void) {
  if (typeof requestIdleCallback === 'function') {
    requestIdleCallback(cb);
  } else {
    setTimeout(cb, 0);
  }
}

export function useSystemKills({
  systemId,
  outCommand,
  showAllVisible = false,
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

        return {
          ...prev,
          detailedKills: updated,
        };
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
          return;
        }

        const callPromise = outCommand({
          type: eventType,
          data: requestData,
        });
        const resp = await withTimeout(callPromise, timeoutMs ?? 0);

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
    },
    [showAllVisible, systemId, outCommand, visibleSystemIds, sinceHours, timeoutMs, mergeKillsIntoGlobal],
  );

  const debouncedFetchKills = useMemo(() => debounce(fetchKills, 500), [fetchKills]);

  useEffect(() => {
    if (!systemId && !showAllVisible && !didFallbackFetch.current) {
      didFallbackFetch.current = true;
      scheduleIdleCallback(() => {
        debouncedFetchKills.cancel();
        fetchKills(true);
      });
    }
  }, [systemId, showAllVisible, debouncedFetchKills, fetchKills]);
  useEffect(() => {
    if (visibleSystemIds.length === 0) return;
    if (showAllVisible || systemId) {
      debouncedFetchKills();
      return () => debouncedFetchKills.cancel();
    }
  }, [showAllVisible, systemId, visibleSystemIds, debouncedFetchKills]);

  const finalKills = useMemo(() => {
    if (showAllVisible || (didFallbackFetch.current && !systemId)) {
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
