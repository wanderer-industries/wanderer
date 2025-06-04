import { useMapRootState } from '@/hooks/Mapper/mapRootProvider';
import { CommandPingAdded, CommandPingCancelled } from '@/hooks/Mapper/types';
import { useCallback, useRef } from 'react';

export const useCommandPings = () => {
  const {
    update,
    data: { pings },
  } = useMapRootState();
  const ref = useRef({ update, pings });
  ref.current = { update, pings };

  const pingAdded = useCallback((pings: CommandPingAdded) => {
    ref.current.update({ pings });
  }, []);

  const pingCancelled = useCallback(({ type, solar_system_id }: CommandPingCancelled) => {
    const newPings = ref.current.pings.filter(x => x.solar_system_id !== solar_system_id && x.type !== type);
    ref.current.update({ pings: newPings });
  }, []);

  return { pingAdded, pingCancelled };
};
