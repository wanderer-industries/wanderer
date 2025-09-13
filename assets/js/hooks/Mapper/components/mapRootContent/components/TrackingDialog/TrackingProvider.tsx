import { createContext, useCallback, useContext, useRef, useState } from 'react';
import { OutCommand, TrackingCharacter } from '@/hooks/Mapper/types';
import { useMapRootState } from '@/hooks/Mapper/mapRootProvider';
import { IncomingEvent, WithChildren } from '@/hooks/Mapper/types/common.ts';
import { CommandInCharactersTrackingInfo } from '@/hooks/Mapper/types/commandsIn.ts';

type DiffTrackingInfo = { characterId: string; tracked: boolean };

type TrackingContextType = {
  loadTracking: () => void;
  updateTracking: (selected: string[]) => void;
  updateFollowing: (characterId: string | null) => void;
  updateMain: (characterId: string) => void;
  trackingCharacters: TrackingCharacter[];
  following: string | null;
  main: string | null;
  loading: boolean;
};

const TrackingContext = createContext<TrackingContextType | undefined>(undefined);

export const TrackingProvider = ({ children }: WithChildren) => {
  const [trackingCharacters, setTrackingCharacters] = useState<TrackingCharacter[]>([]);
  const [following, setFollowing] = useState<string | null>(null);
  const [main, setMain] = useState<string | null>(null);
  const [loading, setLoading] = useState<boolean>(false);

  const { outCommand } = useMapRootState();
  const refVars = useRef({ outCommand, trackingCharacters, following });
  refVars.current = { outCommand, trackingCharacters, following };

  const loadTracking = useCallback(async () => {
    setLoading(true);

    try {
      const res: IncomingEvent<CommandInCharactersTrackingInfo> = await refVars.current.outCommand({
        type: OutCommand.getCharactersTrackingInfo,
        data: {},
      });

      setTrackingCharacters(res.data.characters);
      setFollowing(res.data.following);
      setMain(res.data.main);
    } catch (err) {
      console.error('TrackingProviderError', err);
    }

    setLoading(false);
  }, []);

  const changeTrackingCommand = useCallback(
    async (characterId: string, track: boolean) => {
      try {
        await outCommand({
          type: OutCommand.updateCharacterTracking,
          data: { character_eve_id: characterId, track },
        });
      } catch (error) {
        console.error('Error toggling track:', error);
      }
    },
    [outCommand],
  );

  const updateFollowing = useCallback(
    async (characterId: string | null) => {
      try {
        await outCommand({
          type: OutCommand.updateFollowingCharacter,
          data: { character_eve_id: characterId },
        });
        setFollowing(characterId);
      } catch (error) {
        console.error('Error toggling follow:', error);
      }
    },
    [outCommand],
  );

  const updateTracking = useCallback(
    async (selected: string[]) => {
      const { following, trackingCharacters } = refVars.current;
      const diffToUpdate: DiffTrackingInfo[] = [];

      const newVal = trackingCharacters.map(x => {
        const next = selected.includes(x.character.eve_id);

        if (next !== x.tracked) {
          diffToUpdate.push({ characterId: x.character.eve_id, tracked: next });
        }

        return {
          tracked: selected.includes(x.character.eve_id),
          character: x.character,
        };
      });

      await Promise.all(diffToUpdate.map(x => changeTrackingCommand(x.characterId, x.tracked)));

      if (newVal.some(x => following != null && x.character.eve_id === following && !x.tracked)) {
        await updateFollowing(null);
        setFollowing(null);
      }

      setTrackingCharacters(newVal);
    },
    [changeTrackingCommand, updateFollowing],
  );

  const updateMain = useCallback(
    async (characterId: string) => {
      try {
        await outCommand({
          type: OutCommand.updateMainCharacter,
          data: { character_eve_id: characterId },
        });
        setMain(characterId);
      } catch (error) {
        console.error('Error toggling main:', error);
      }
    },
    [outCommand],
  );

  return (
    <TrackingContext.Provider
      value={{
        loadTracking,
        trackingCharacters,
        following,
        main,
        loading,
        updateTracking,
        updateFollowing,
        updateMain,
      }}
    >
      {children}
    </TrackingContext.Provider>
  );
};

export const useTracking = () => {
  const context = useContext(TrackingContext);
  if (!context) {
    throw new Error('useTracking must be used within a TrackingProvider');
  }
  return context;
};
