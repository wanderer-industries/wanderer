import { useState, useEffect } from 'react';
import { Dialog } from 'primereact/dialog';
import { TrackingCharacterWrapper } from './TrackingCharacterWrapper';
import styles from './TrackAndFollow.module.scss';
import { TrackingCharacter } from './types';
import { useMapRootState } from '@/hooks/Mapper/mapRootProvider';
import { OutCommand } from '@/hooks/Mapper/types/mapHandlers';

interface TrackAndFollowProps {
  visible: boolean;
  onHide: () => void;
  characters: TrackingCharacter[];
}

export const TrackAndFollow = ({ visible, onHide, characters }: TrackAndFollowProps) => {
  const [trackedCharacters, setTrackedCharacters] = useState<string[]>([]);
  const [followedCharacter, setFollowedCharacter] = useState<string | null>(null);
  const { outCommand } = useMapRootState();

  // Initialize local state with server state when characters change or dialog becomes visible
  useEffect(() => {
    if (visible && characters.length > 0) {
      // Initialize tracked characters from server data
      const tracked = characters.filter(char => char.tracked).map(char => char.id);
      setTrackedCharacters(tracked);

      // Initialize followed character from server data
      const followed = characters.find(char => char.followed);
      setFollowedCharacter(followed ? followed.id : null);
    }
  }, [visible, characters]);

  const handleTrackToggle = (characterId: string) => {
    setTrackedCharacters(prev => {
      if (prev.includes(characterId)) {
        if (followedCharacter === characterId) {
          setFollowedCharacter(null);
          outCommand({
            type: OutCommand.toggleFollow,
            data: { 'character-id': characterId },
          });
        }
        return prev.filter(id => id !== characterId);
      } else {
        return [...prev, characterId];
      }
    });

    outCommand({
      type: OutCommand.toggleTrack,
      data: { 'character-id': characterId },
    });
  };

  const handleFollowToggle = (characterId: string) => {
    if (followedCharacter !== characterId) {
      if (!trackedCharacters.includes(characterId)) {
        setTrackedCharacters(prev => [...prev, characterId]);
        outCommand({
          type: OutCommand.toggleTrack,
          data: { 'character-id': characterId },
        });
      }
    }

    setFollowedCharacter(prev => (prev === characterId ? null : characterId));

    outCommand({
      type: OutCommand.toggleFollow,
      data: { 'character-id': characterId },
    });
  };

  const renderHeader = () => {
    return (
      <div className="dialog-header">
        <span>Track & Follow</span>
      </div>
    );
  };

  return (
    <Dialog
      header={renderHeader}
      visible={visible}
      style={{ width: '500px' }}
      onHide={onHide}
      modal
      className="p-fluid"
      closeOnEscape
      appendTo={document.body}
      showHeader={true}
      closable={true}
    >
      <div className={styles['character-grid']}>
        <div className={styles['character-grid-header']}>
          <div>Track</div>
          <div>Follow</div>
          <div>Character</div>
        </div>
        <div className={styles['character-grid-body']}>
          {characters.map(character => (
            <TrackingCharacterWrapper
              key={character.id}
              character={character}
              isTracked={trackedCharacters.includes(character.id)}
              isFollowed={followedCharacter === character.id}
              onTrackToggle={() => handleTrackToggle(character.id)}
              onFollowToggle={() => handleFollowToggle(character.id)}
            />
          ))}
        </div>
      </div>
    </Dialog>
  );
};
