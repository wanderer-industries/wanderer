import { OutCommand } from '@/hooks/Mapper/types/mapHandlers.ts';
import { useMapRootState } from '@/hooks/Mapper/mapRootProvider';

export const useDeleteSystems = () => {
  const { outCommand } = useMapRootState();

  const deleteSystems = (systemIds: string[]) => {
    if (!systemIds || !systemIds.length) {
      return;
    }

    outCommand({ type: OutCommand.deleteSystems, data: systemIds });
  };

  return {
    deleteSystems,
  };
};
