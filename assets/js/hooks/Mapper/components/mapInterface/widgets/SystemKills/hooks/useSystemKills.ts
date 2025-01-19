import { useCallback, useMemo, useState, useEffect, useRef } from 'react';
import debounce from 'lodash.debounce';
import { OutCommand } from '@/hooks/Mapper/types/mapHandlers';
import { DetailedKill } from '@/hooks/Mapper/types/kills';
import { useMapRootState } from '@/hooks/Mapper/mapRootProvider';

interface UseSystemKillsProps {
  systemId?: string;
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  outCommand: (payload: any) => Promise<any>;
  showAllVisible?: boolean;
  sinceHours?: number;
}

function combineKills(existing: DetailedKill[], incoming: DetailedKill[], sinceHours: number): DetailedKill[] {
  const cutoff = Date.now() - sinceHours * 60 * 60 * 1000;
  const byId: Record<string, DetailedKill> = {};

  for (const kill of [...existing, ...incoming]) {
    if (!kill.kill_time) {
      continue;
    }
    const killTimeMs = new Date(kill.kill_time).valueOf();

    if (killTimeMs >= cutoff) {
      byId[kill.killmail_id] = kill;
    }
  }

  return Object.values(byId);
}

/**
 * The main hook that fetches kills for either:
 *  - the chosen `systemId`, or
 *  - all visible systems if `showAllVisible=true`.
 *
 * It returns:
 * - `kills` => combined kills from global state
 * - `isLoading` => whether a fetch is ongoing and no data is in memory yet
 * - `error` => any error string
 * - `refetch` => manual immediate fetch (bypasses debounce)
 */
export function useSystemKills({ systemId, outCommand, showAllVisible = false, sinceHours = 24 }: UseSystemKillsProps) {
  const { data, update } = useMapRootState();
  const { detailedKills = {}, systems = [] } = data;

  const visibleSystemIds = useMemo(() => systems.map(s => s.id), [systems]);

  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  // Used to track if we did a fallback fetch once
  const didFallbackFetch = useRef(false);

  const mergeKillsIntoGlobal = useCallback(
    (killsMap: Record<string, DetailedKill[]>) => {
      update(prev => {
        const oldMap = prev.detailedKills ?? {};
        const updated: Record<string, DetailedKill[]> = { ...oldMap };

        for (const [sid, newKills] of Object.entries(killsMap)) {
          const existing = updated[sid] ?? [];
          const combined = combineKills(existing, newKills, sinceHours);
          updated[sid] = combined;
        }

        return {
          ...prev,
          detailedKills: updated,
        };
      });
    },
    [update, sinceHours],
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
          // If there's no system and not showing all, do nothing
          setIsLoading(false);
          return;
        }

        const resp = await outCommand({
          type: eventType,
          data: requestData,
        });

        // Single system => `resp.kills`
        if (resp.kills) {
          const arr = resp.kills as DetailedKill[];
          const sid = systemId ?? 'unknown';
          mergeKillsIntoGlobal({ [sid]: arr });
        }
        // multiple => `resp.systems_kills`
        else if (resp.systems_kills) {
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
    [showAllVisible, systemId, outCommand, visibleSystemIds, sinceHours, mergeKillsIntoGlobal],
  );

  /**
   * Debounced version of fetchKills used in useEffects.
   *
   * `leading: true` => run immediately on the first call in a burst
   * `trailing: true` => run again at the end of the wait period
   *
   */
  const debouncedFetchKills = useMemo(
    () =>
      debounce(fetchKills, 500, {
        leading: true,
        trailing: false,
      }),
    [fetchKills],
  );

  /**
   * finalKills => computed from the global `detailedKills`,
   * depending on showAllVisible or a single system.
   */
  const finalKills = useMemo(() => {
    if (showAllVisible) {
      return visibleSystemIds.flatMap(sid => detailedKills[sid] ?? []);
    } else if (systemId) {
      return detailedKills[systemId] ?? [];
    } else if (didFallbackFetch.current) {
      // if we already did a fallback, we may have data for multiple systems
      return visibleSystemIds.flatMap(sid => detailedKills[sid] ?? []);
    }
    return [];
  }, [showAllVisible, systemId, visibleSystemIds, detailedKills]);

  /**
   * If we are loading and we have NO kills yet, we are effectively "loading."
   * If we do have kills, we can show them while the fetch is in progress.
   */
  const effectiveIsLoading = isLoading && finalKills.length === 0;

  /**
   * useEffect #1 => fallback fetch if we have no system
   * and are not "showAll."
   */
  useEffect(() => {
    if (!systemId && !showAllVisible && !didFallbackFetch.current) {
      didFallbackFetch.current = true;
      // Cancel any queued debounced calls, then do the fallback.
      debouncedFetchKills.cancel();
      fetchKills(true); // forceFallback => fetch as though showAll
    }
  }, [systemId, showAllVisible, debouncedFetchKills, fetchKills]);

  /**
   * useEffect #2 => if we do have showAll or a system,
   * we do a normal debounced fetch.
   */
  useEffect(() => {
    if (visibleSystemIds.length === 0) return;

    if (showAllVisible || systemId) {
      debouncedFetchKills();
      // Clean up the debounce on unmount or changes
      return () => debouncedFetchKills.cancel();
    }
  }, [showAllVisible, systemId, visibleSystemIds, debouncedFetchKills]);

  const refetch = useCallback(() => {
    debouncedFetchKills.cancel();
    fetchKills(); // immediate (non-debounced) call
  }, [debouncedFetchKills, fetchKills]);

  return {
    kills: finalKills,
    isLoading: effectiveIsLoading,
    error,
    refetch,
  };
}
