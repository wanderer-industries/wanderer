import { useState, useEffect, useMemo } from 'react';
import { Dialog } from 'primereact/dialog';
import { VirtualScroller } from 'primereact/virtualscroller';
import { useMapRootState } from '@/hooks/Mapper/mapRootProvider';
import { OutCommand } from '@/hooks/Mapper/types/mapHandlers';
import { TrackingCharacterWrapper } from './TrackingCharacterWrapper';
import { TrackingCharacter } from './types';
import classes from './TrackAndFollow.module.scss';

interface TrackAndFollowProps {
  visible: boolean;
  onHide: () => void;
}

const renderHeader = () => {
  return (
    <div className="dialog-header">
      <span>Track & Follow</span>
    </div>
  );
};

export const TrackAndFollow = ({ visible, onHide }: TrackAndFollowProps) => {
  const [trackedCharacters, setTrackedCharacters] = useState<string[]>([]);
  const [followedCharacter, setFollowedCharacter] = useState<string | null>(null);
  const { outCommand, data } = useMapRootState();
  const { trackingCharactersData } = data;
  const characters = useMemo(() => trackingCharactersData || [], [trackingCharactersData]);

  useEffect(() => {
    if (trackingCharactersData) {
      const newTrackedCharacters = trackingCharactersData
        .filter(character => character.tracked)
        .map(character => character.id);

      setTrackedCharacters(newTrackedCharacters);

      const followedChar = trackingCharactersData.find(character => character.followed);

      if (followedChar?.id !== followedCharacter) {
        setFollowedCharacter(followedChar?.id || null);
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

  const handleFollowToggle = (characterId: string) => {
    const isCurrentlyFollowed = followedCharacter === characterId;
    const isCurrentlyTracked = trackedCharacters.includes(characterId);

    // If not followed and not tracked, we need to track it first
    if (!isCurrentlyFollowed && !isCurrentlyTracked) {
      setTrackedCharacters(prev => [...prev, characterId]);

      // Send track command first
      outCommand({
        type: OutCommand.toggleTrack,
        data: { 'character-id': characterId },
      });

      // Then send follow command after a short delay
      setTimeout(() => {
        outCommand({
          type: OutCommand.toggleFollow,
          data: { 'character-id': characterId },
        });
      }, 100);

      return;
    }

    // Otherwise just toggle follow
    outCommand({
      type: OutCommand.toggleFollow,
      data: { 'character-id': characterId },
    });
  };

  const rowTemplate = (character: TrackingCharacter) => {
    return (
      <TrackingCharacterWrapper
        key={character.id}
        character={character}
        isTracked={trackedCharacters.includes(character.id)}
        isFollowed={followedCharacter === character.id}
        onTrackToggle={() => handleTrackToggle(character.id)}
        onFollowToggle={() => handleFollowToggle(character.id)}
      />
    );
  };

  return (
    <Dialog
      header={renderHeader()}
      visible={visible}
      onHide={onHide}
      className="w-[500px] bg-surface-card text-text-color"
    >
      <div className="w-full overflow-hidden">
        <div
          className={`
            grid grid-cols-[80px_80px_1fr] 
            ${classes.trackFollowHeader} 
            border-b border-surface-border 
            font-normal text-sm text-text-color 
            p-0.5 text-center
          `}
        >
          <div>Track</div>
          <div>Follow</div>
          <div className="text-center">Character</div>
        </div>
        <VirtualScroller items={characters} itemSize={48} itemTemplate={rowTemplate} className="h-72 w-full" />
      </div>
    </Dialog>
  );
};
