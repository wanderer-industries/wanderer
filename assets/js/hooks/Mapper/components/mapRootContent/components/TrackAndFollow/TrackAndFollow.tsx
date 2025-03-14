import { useEffect, useMemo, useState } from 'react';
import { Dialog } from 'primereact/dialog';
import { VirtualScroller } from 'primereact/virtualscroller';
import { useMapRootState } from '@/hooks/Mapper/mapRootProvider';
import { OutCommand } from '@/hooks/Mapper/types/mapHandlers';
import { TrackingCharacterWrapper } from './TrackingCharacterWrapper';
import { TrackingCharacter } from './types';

interface TrackAndFollowProps {
  visible: boolean;
  onHide: () => void;
}

export const TrackAndFollow = ({ visible, onHide }: TrackAndFollowProps) => {
  const [trackedCharacters, setTrackedCharacters] = useState<string[]>([]);
  const [followedCharacter, setFollowedCharacter] = useState<string | null>(null);
  const { outCommand, data } = useMapRootState();
  const { trackingCharactersData } = data;
  const characters = useMemo(() => trackingCharactersData || [], [trackingCharactersData]);

  useEffect(() => {
    if (trackingCharactersData) {
      const newTrackedCharacters = trackingCharactersData.filter(tc => tc.tracked).map(tc => tc.character.eve_id);

      setTrackedCharacters(newTrackedCharacters);

      const followedChar = trackingCharactersData.find(tc => tc.followed);

      if (followedChar?.character?.eve_id !== followedCharacter) {
        setFollowedCharacter(followedChar?.character?.eve_id || null);
      }
    }
  }, [followedCharacter, trackingCharactersData]);

  const handleTrackToggle = (characterId: string) => {
    const isCurrentlyTracked = trackedCharacters.includes(characterId);

    if (isCurrentlyTracked) {
      setTrackedCharacters(prev => prev.filter(id => id !== characterId));
    } else {
      setTrackedCharacters(prev => [...prev, characterId]);
    }

    outCommand({
      type: OutCommand.toggleTrack,
      data: { 'character-id': characterId },
    });
  };

  const handleFollowToggle = async (characterEveId: string) => {
    const isCurrentlyFollowed = followedCharacter === characterEveId;
    const isCurrentlyTracked = trackedCharacters.includes(characterEveId);

    // If not followed and not tracked, we need to track it first
    if (!isCurrentlyFollowed && !isCurrentlyTracked) {
      setTrackedCharacters(prev => [...prev, characterEveId]);

      // Send track command first
      await outCommand({
        type: OutCommand.toggleTrack,
        data: { 'character-id': characterEveId },
      });

      // Then send follow command after a short delay
      setTimeout(() => {
        outCommand({
          type: OutCommand.toggleFollow,
          data: { 'character-id': characterEveId },
        });
      }, 100);
    } else {
      // Otherwise just toggle follow
      await outCommand({
        type: OutCommand.toggleFollow,
        data: { 'character-id': characterEveId },
      });
    }
  };

  const rowTemplate = (tc: TrackingCharacter) => {
    return (
      <TrackingCharacterWrapper
        key={tc.character.eve_id}
        character={tc.character}
        isTracked={trackedCharacters.includes(tc.character.eve_id)}
        isFollowed={followedCharacter === tc.character.eve_id}
        onTrackToggle={() => handleTrackToggle(tc.character.eve_id)}
        onFollowToggle={() => handleFollowToggle(tc.character.eve_id)}
      />
    );
  };

  return (
    <Dialog
      header={
        <div className="dialog-header">
          <span>Track & Follow</span>
        </div>
      }
      visible={visible}
      onHide={onHide}
      className="w-[500px] text-text-color"
      contentClassName="!p-0"
    >
      <div className="w-full overflow-hidden">
        <div className="grid grid-cols-[80px_80px_1fr] p-1 font-normal text-sm text-center border-b border-[#383838]">
          <div>Track</div>
          <div>Follow</div>
          <div className="text-center">Character</div>
        </div>
        <VirtualScroller items={characters} itemSize={48} itemTemplate={rowTemplate} className="h-72 w-full" />
      </div>
    </Dialog>
  );
};
