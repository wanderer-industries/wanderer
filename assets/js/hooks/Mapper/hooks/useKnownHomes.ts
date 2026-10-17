import { useCallback, useEffect, useRef, useState } from 'react';
import { OutCommand, OutCommandHandler, SolarSystemConnection, SolarSystemRawType } from '@/hooks/Mapper/types';

export type KnownHome = {
  map_id?: string;
  share_id?: string;
  map_name: string;
  map_slug: string;
  solar_system_id: number;
  'remote?'?: boolean;
};

export type HomeMarker = { holes: number; home: boolean; mouth: boolean };

export type HomeWaysIn = {
  home: { map_name: string; map_slug: string; solar_system_id: number };
  // the same shape the map is given for its own systems, so it can be drawn with the map's
  // renderer rather than one written for this dialog
  ways_in: {
    systems: SolarSystemRawType[];
    connections: SolarSystemConnection[];
    markers: Record<string, HomeMarker>;
  };
};

/**
 * The homes other maps have declared, keyed by the system they sit in.
 *
 * Only maps this person may already open come back, so a marker on the chain never says more
 * than they could find by opening those maps themselves.
 */
export const useKnownHomes = (outCommand: OutCommandHandler, ready: boolean) => {
  const [homes, setHomes] = useState<Record<string, KnownHome>>({});
  const ref = useRef({ outCommand });
  ref.current = { outCommand };

  useEffect(() => {
    if (!ready) {
      return;
    }

    let current = true;

    const load = async () => {
      try {
        const res = await ref.current.outCommand<{ homes?: KnownHome[] }>({
          type: OutCommand.getKnownHomes,
          data: {},
        });

        if (current) {
          setHomes(Object.fromEntries((res?.homes ?? []).map(home => [`${home.solar_system_id}`, home])));
        }
      } catch {
        if (current) {
          setHomes({});
        }
      }
    };

    load();

    return () => {
      current = false;
    };
  }, [ready]);

  const waysIn = useCallback(async (home: KnownHome) => {
    const res = await ref.current.outCommand<HomeWaysIn & { error?: string }>({
      type: OutCommand.getHomeWaysIn,
      data: home.share_id
        ? { share_id: home.share_id }
        : { map_id: home.map_id, solar_system_id: home.solar_system_id },
    });

    return res?.error ? undefined : res;
  }, []);

  return { homes, waysIn };
};
