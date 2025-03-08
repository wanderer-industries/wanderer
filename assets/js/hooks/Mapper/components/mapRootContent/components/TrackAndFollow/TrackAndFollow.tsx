import { useState, useEffect, useMemo } from 'react';
import { Dialog } from 'primereact/dialog';
import { VirtualScroller } from 'primereact/virtualscroller';
import classes from './TrackAndFollow.module.scss';
import { useMapRootState } from '@/hooks/Mapper/mapRootProvider';
import { OutCommand } from '@/hooks/Mapper/types/mapHandlers';
import { TrackingCharacterWrapper } from './TrackingCharacterWrapper';
import { TrackingCharacter } from './types';

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
    if (!visible || characters.length === 0) {
      return;
    }
    const tracked = characters.filter(char => char.tracked).map(char => char.id);
    setTrackedCharacters(tracked);

    const followed = characters.find(char => char.followed);
    setFollowedCharacter(followed ? followed.id : null);
  }, [visible, characters]);

  const handleTrackToggle = (characterId: string) => {
    setTrackedCharacters(prev => {
      if (!prev.includes(characterId)) {
        return [...prev, characterId];
      }
      if (followedCharacter === characterId) {
        setFollowedCharacter(null);
        outCommand({
          type: OutCommand.toggleFollow,
          data: { 'character-id': characterId },
        });
      }
      return prev.filter(id => id !== characterId);
    });
    outCommand({
      type: OutCommand.toggleTrack,
      data: { 'character-id': characterId },
    });
  };

  const handleFollowToggle = (characterId: string) => {
    if (followedCharacter !== characterId && !trackedCharacters.includes(characterId)) {
      setTrackedCharacters(prev => [...prev, characterId]);
      outCommand({
        type: OutCommand.toggleTrack,
        data: { 'character-id': characterId },
      });
    }
    setFollowedCharacter(prev => (prev === characterId ? null : characterId));
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
      modal
      className={classes.trackFollowDialog}
      closeOnEscape
      showHeader={true}
      closable={true}
    >
      <div className={classes.characterGrid}>
        <div className={classes.characterGridHeader}>
          <div>Track</div>
          <div>Follow</div>
          <div>Character</div>
        </div>
        <VirtualScroller
          items={characters}
          itemSize={48}
          itemTemplate={rowTemplate}
          className={`${classes.characterGridBody} h-72 w-full`}
        />
      </div>
    </Dialog>
  );
};
