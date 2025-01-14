import { useEffect, useState, useCallback } from 'react';
import { OutCommand } from '@/hooks/Mapper/types/mapHandlers';
import { mapServerStructure, getActualStructures, StructureItem, statusesRequiringTimer } from '../helpers';

interface UseSystemStructuresProps {
  systemId: string | undefined;
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  outCommand: (payload: any) => Promise<any>;
}

export function useSystemStructures({ systemId, outCommand }: UseSystemStructuresProps) {
  const [structures, setStructures] = useState<StructureItem[]>([]);
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const fetchStructures = useCallback(async () => {
    if (!systemId) {
      setStructures([]);
      return;
    }
    setIsLoading(true);
    setError(null);

    try {
      const { structures: fetched = [] } = await outCommand({
        type: OutCommand.getStructures,
        data: { system_id: systemId },
      });

      const mappedStructures = fetched.map(mapServerStructure);
      setStructures(mappedStructures);
    } catch (err) {
      console.error('Failed to get structures:', err);
      setError('Error fetching structures');
    } finally {
      setIsLoading(false);
    }
  }, [systemId, outCommand]);

  useEffect(() => {
    fetchStructures();
  }, [fetchStructures]);

  const sanitizeEndTimers = useCallback((item: StructureItem) => {
    if (!statusesRequiringTimer.includes(item.status)) {
      item.endTime = '';
    }
    return item;
  }, []);

  const sanitizeIds = useCallback((item: StructureItem) => {
    // eslint-disable-next-line @typescript-eslint/no-unused-vars
    const { id, ...rest } = item;
    return rest;
  }, []);

  const handleUpdateStructures = useCallback(
    async (newList: StructureItem[]) => {
      const { added, updated, removed } = getActualStructures(structures, newList);

      const sanitizedAdded = added.map(sanitizeIds);
      const sanitizedUpdated = updated.map(sanitizeEndTimers);

      try {
        const { structures: updatedStructures = [] } = await outCommand({
          type: OutCommand.updateStructures,
          data: {
            system_id: systemId,
            added: sanitizedAdded,
            updated: sanitizedUpdated,
            removed,
          },
        });

        const finalStructures = updatedStructures.map(mapServerStructure);
        setStructures(finalStructures);
      } catch (err) {
        console.error('Failed to update structures:', err);
      }
    },
    [structures, systemId, outCommand, sanitizeIds, sanitizeEndTimers],
  );

  return { structures, handleUpdateStructures, isLoading, error };
}
