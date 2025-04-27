import { useCallback, useRef } from 'react';
import { CommandMapUpdated } from '@/hooks/Mapper/types/mapHandlers.ts';
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

    if ('system_signatures' in props) {
      out.systemSignatures = props.system_signatures;
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

    update(out);
  }, []);
};
