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
}

export function useSystemKills({ systemId, outCommand, showAllVisible }: UseSystemKillsProps) {
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

  const fetchKills = useCallback(async () => {
    setIsLoading(true);
    setError(null);

    try {
      let eventType: OutCommand;
      let requestData: Record<string, unknown>;

      if (showAllVisible || (!systemId && !didFallbackFetch.current)) {
        eventType = OutCommand.getSystemsKills;
        requestData = {
          system_ids: visibleSystemIds,
          since_hours: 24,
        };
        if (!systemId && !showAllVisible) {
          didFallbackFetch.current = true;
        }
      } else if (systemId) {
        eventType = OutCommand.getSystemKills;
        requestData = {
          system_id: systemId,
          since_hours: 24,
        };
      } else {
        return;
      }

      const resp = await outCommand({ type: eventType, data: requestData });

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
      setError('Error fetching kills');
    } finally {
      setIsLoading(false);
    }
  }, [showAllVisible, systemId, visibleSystemIds, outCommand, mergeKillsIntoGlobal]);

  const debouncedFetchKills = useMemo(() => debounce(fetchKills, 500), [fetchKills]);

  useEffect(() => {
    if (visibleSystemIds.length === 0) {
      return;
    }
    debouncedFetchKills();
    return () => debouncedFetchKills.cancel();
  }, [debouncedFetchKills, showAllVisible, systemId, visibleSystemIds]);

  const finalKills = useMemo(() => {
    if (showAllVisible || (!systemId && didFallbackFetch.current)) {
      return visibleSystemIds.flatMap(sid => detailedKills[sid] ?? []);
    }
    if (systemId) {
      return detailedKills[systemId] ?? [];
    }
    return [];
  }, [showAllVisible, systemId, visibleSystemIds, detailedKills]);

  const effectiveIsLoading = isLoading && finalKills.length === 0;

  return {
    kills: finalKills,
    isLoading: effectiveIsLoading,
    error,
    refetch: fetchKills,
  };
}
