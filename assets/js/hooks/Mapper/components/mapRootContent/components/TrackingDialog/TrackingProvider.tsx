import { createContext, useCallback, useContext, useRef, useState, useEffect, useMemo } from 'react';
import { OutCommand, TrackingCharacter } from '@/hooks/Mapper/types';
import { useMapRootState } from '@/hooks/Mapper/mapRootProvider';
import { IncomingEvent, WithChildren } from '@/hooks/Mapper/types/common.ts';
import { CommandInCharactersTrackingInfo } from '@/hooks/Mapper/types/commandsIn.ts';

type DiffTrackingInfo = { characterId: string; tracked: boolean };

interface UpdateReadyResponse {
  data?: unknown;
  error?: string;
  message?: string;
  remaining_cooldown?: number;
}

// Type guard to check if response is an UpdateReadyResponse with error
function isUpdateReadyResponseWithError(response: unknown): response is UpdateReadyResponse & { error: string } {
  return (
    typeof response === 'object' &&
    response !== null &&
    'error' in response &&
    typeof (response as UpdateReadyResponse).error === 'string'
  );
}

type TrackingContextType = {
  loadTracking: () => void;
  updateTracking: (selected: string[]) => void;
  updateFollowing: (characterId: string | null) => void;
  updateMain: (characterId: string) => void;
  updateReady: (readyCharacterIds: string[]) => Promise<unknown>;
  trackingCharacters: TrackingCharacter[];
  following: string | null;
  main: string | null;
  ready: string[];
  loading: boolean;
};

const TrackingContext = createContext<TrackingContextType | undefined>(undefined);

export const TrackingProvider = ({ children }: WithChildren) => {
  const [trackingCharacters, setTrackingCharacters] = useState<TrackingCharacter[]>([]);
  const [following, setFollowing] = useState<string | null>(null);
  const [main, setMain] = useState<string | null>(null);
  const [ready, setReady] = useState<string[]>([]);
  const [loading, setLoading] = useState<boolean>(false);

  const { outCommand, data } = useMapRootState();
  const refVars = useRef({ outCommand, trackingCharacters, following });
  refVars.current = { outCommand, trackingCharacters, following };

  // Memoize the ready characters array to avoid recalculations
  const globalReadyCharacters = useMemo(() => {
    return data.characters?.filter(char => char.ready)?.map(char => char.eve_id) || [];
  }, [data.characters]);

  // Sync ready state with global character data - only update if values actually changed
  useEffect(() => {
    setReady(prevReady => {
      // Only update if the arrays are different
      if (
        prevReady.length !== globalReadyCharacters.length ||
        !prevReady.every(id => globalReadyCharacters.includes(id))
      ) {
        return globalReadyCharacters;
      }
      return prevReady;
    });

    // Also update the ready status in trackingCharacters
    setTrackingCharacters(prev =>
      prev.map(trackingChar => ({
        ...trackingChar,
        ready: globalReadyCharacters.includes(trackingChar.character.eve_id),
      })),
    );
  }, [globalReadyCharacters]);

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
      setReady(res.data.ready_characters);
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
          ready: x.ready,
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

  const updateReady = useCallback(
    async (readyCharacterIds: string[]) => {
      try {
        const response = await outCommand({
          type: OutCommand.updateReadyCharacters,
          data: { ready_character_eve_ids: readyCharacterIds },
        });

        // Check if the response indicates a rate limit error
        if (isUpdateReadyResponseWithError(response)) {
          throw response;
        }

        // Update local state immediately
        setReady(readyCharacterIds);

        // Also update trackingCharacters to reflect ready status
        setTrackingCharacters(prev =>
          prev.map(char => ({
            ...char,
            ready: readyCharacterIds.includes(char.character.eve_id),
          })),
        );

        return response;
      } catch (error) {
        console.error('Error updating ready characters:', error);
        throw error;
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
        ready,
        loading,
        updateTracking,
        updateFollowing,
        updateMain,
        updateReady,
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
