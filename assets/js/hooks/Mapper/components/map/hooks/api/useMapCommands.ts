import { MapData, useMapState } from '@/hooks/Mapper/components/map/MapProvider.tsx';
import { CommandKillsUpdated, CommandMapUpdated } from '@/hooks/Mapper/types';
import { useCallback, useRef } from 'react';

export const useMapCommands = () => {
  const { update } = useMapState();

  const ref = useRef({ update });
  ref.current = { update };

  const mapUpdated = useCallback(({ hubs, system_signatures, kills }: CommandMapUpdated) => {
    const out: Partial<MapData> = {};

    if (hubs) {
      out.hubs = hubs;
    }

    if (system_signatures) {
      out.systemSignatures = system_signatures;
    }

    if (kills) {
      out.kills = kills.reduce((acc, x) => ({ ...acc, [x.solar_system_id]: x.kills }), {});
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
