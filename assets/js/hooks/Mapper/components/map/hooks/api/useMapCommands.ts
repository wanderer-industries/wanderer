import { MapData, useMapState } from '@/hooks/Mapper/components/map/MapProvider.tsx';
import { useCallback, useRef } from 'react';
import { CommandKillsUpdated, CommandMapUpdated } from '@/hooks/Mapper/types';

export const useMapCommands = () => {
  const { update } = useMapState();

  const ref = useRef({ update });
  ref.current = { update };

  const mapUpdated = useCallback(({ hubs }: CommandMapUpdated) => {
    const out: Partial<MapData> = {};

    if (hubs) {
      out.hubs = hubs;
    }

    ref.current.update(out);
  }, []);

  const killsUpdated = useCallback((updated_kills: CommandKillsUpdated) => {
    ref.current.update(({ kills }) => {
      updated_kills.forEach(kill => {
        kills[kill.solar_system_id] = kill.kills;
      });

      return { kills: { ...kills } };
    });
  }, []);

  return { mapUpdated, killsUpdated };
};
