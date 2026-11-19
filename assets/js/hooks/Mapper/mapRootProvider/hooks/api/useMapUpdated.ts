import { useCallback, useRef } from 'react';
import { CommandMapUpdated } from '@/hooks/Mapper/types/mapHandlers.ts';
import { SignatureGroup } from '@/hooks/Mapper/types';
import { MapRootData, useMapRootState } from '@/hooks/Mapper/mapRootProvider';

export const useMapUpdated = () => {
  const { update } = useMapRootState();

  const ref = useRef({ update });
  ref.current = { update };

  return useCallback((props: CommandMapUpdated) => {
    const { update } = ref.current;

    const out: Partial<MapRootData> = {};

    if ('hubs' in props) {
      out.hubs = props.hubs;
    }

    if ('user_hubs' in props) {
      out.userHubs = props.user_hubs;
    }

    if ('following_character_eve_id' in props) {
      out.userCharacters = props.user_characters;
    }

    if ('following_character_eve_id' in props) {
      out.followingCharacterEveId = props.following_character_eve_id;
    }

    if ('main_character_eve_id' in props) {
      out.mainCharacterEveId = props.main_character_eve_id;
    }

    if ('system_signatures' in props && props.system_signatures) {
      update(prev => {
        const merged = { ...(prev.systemSignatures || {}), ...props.system_signatures };
        for (const [sysId, existingSigs] of Object.entries(prev.systemSignatures || {})) {
          if (
            sysId in props.system_signatures &&
            existingSigs &&
            existingSigs.some(s => s.group !== SignatureGroup.Wormhole)
          ) {
            const incomingWormholeSigs = props.system_signatures[sysId] || [];
            const incomingEveIds = new Set(incomingWormholeSigs.map(s => s.eve_id));
            const preservedNonWormholeSigs = existingSigs.filter(
              s => s.group !== SignatureGroup.Wormhole && !incomingEveIds.has(s.eve_id),
            );
            merged[sysId] = [...incomingWormholeSigs, ...preservedNonWormholeSigs];
          }
        }
        return { ...out, systemSignatures: merged };
      });
      return;
    }

    update(out);
  }, []);
};
