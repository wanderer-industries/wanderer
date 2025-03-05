import { TrackingCharacter } from './types';
import { Tooltip } from 'primereact/tooltip';
import { WdCheckbox } from '@/hooks/Mapper/components/ui-kit/WdCheckbox/WdCheckbox';
import WdRadioButton from '@/hooks/Mapper/components/ui-kit/WdRadioButton';
import styles from './TrackAndFollow.module.scss';

interface TrackingCharacterWrapperProps {
  character: TrackingCharacter;
  isTracked: boolean;
  isFollowed: boolean;
  onTrackToggle: () => void;
  onFollowToggle: () => void;
}

/**
 * Component to display a single tracking character with track/follow controls
 */
export const TrackingCharacterWrapper = ({
  character,
  isTracked,
  isFollowed,
  onTrackToggle,
  onFollowToggle,
}: TrackingCharacterWrapperProps) => {
  const trackCheckboxId = `track-${character.id}`;
  const followRadioId = `follow-${character.id}`;

  return (
    <div className={styles['character-grid-row']}>
      <div className={styles['grid-cell-track']}>
        <Tooltip target={`#${trackCheckboxId}`} content="Track this character on the map" position="top" />
        <div className={styles['checkbox-container']}>
          <WdCheckbox label="" value={isTracked} onChange={() => onTrackToggle()} />
        </div>
      </div>
      <div className={styles['grid-cell-follow']}>
        <Tooltip target={`#${followRadioId}`} content="Follow this character's movements on the map" position="top" />
        <div className={styles['radio-container']}>
          <WdRadioButton
            id={followRadioId}
            name="followed_character"
            checked={isFollowed}
            onChange={() => onFollowToggle()}
          />
        </div>
      </div>
      <div className={styles['grid-cell-character']}>
        <div className={styles['character-info']}>
          <div className={styles['character-portrait']}>
            <img src={character.portrait_url} alt={character.name} className={styles['portrait-image']} />
          </div>
          <div className={styles['character-details']}>
            <span className={styles['character-name']}>{character.name}</span>
            <span className={styles['corporation-ticker']}>[{character.corporation_ticker}]</span>
            {character.alliance_ticker && (
              <span className={styles['alliance-ticker']}>[{character.alliance_ticker}]</span>
            )}
          </div>
        </div>
      </div>
    </div>
  );
};
