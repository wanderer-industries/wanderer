import { TrackingCharacter } from './types';
import { Tooltip } from 'primereact/tooltip';
import { WdCheckbox } from '@/hooks/Mapper/components/ui-kit/WdCheckbox/WdCheckbox';
import WdRadioButton from '@/hooks/Mapper/components/ui-kit/WdRadioButton';
import classes from './TrackingCharacterWrapper.module.scss';

interface TrackingCharacterWrapperProps {
  character: TrackingCharacter;
  isTracked: boolean;
  isFollowed: boolean;
  onTrackToggle: () => void;
  onFollowToggle: () => void;
}

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
    <div className={classes.characterGridRow}>
      <div className={classes.gridCellTrack}>
        <Tooltip target={`#${trackCheckboxId}`} content="Track this character on the map" position="top" />
        <div className={classes.checkboxContainer}>
          <WdCheckbox label="" value={isTracked} onChange={() => onTrackToggle()} />
        </div>
      </div>
      <div className={classes.gridCellFollow}>
        <Tooltip target={`#${followRadioId}`} content="Follow this character's movements on the map" position="top" />
        <div className={classes.radioContainer}>
          <WdRadioButton
            id={followRadioId}
            name="followed_character"
            checked={isFollowed}
            onChange={() => onFollowToggle()}
          />
        </div>
      </div>
      <div className={classes.gridCellCharacter}>
        <div className={classes.characterInfo}>
          <div className={classes.characterPortrait}>
            <img src={character.portrait_url} alt={character.name} className={classes.portraitImage} />
          </div>
          <div className={classes.characterDetails}>
            <span className={classes.characterName}>{character.name}</span>
            <span className={classes.corporationTicker}>[{character.corporation_ticker}]</span>
            {character.alliance_ticker && <span className={classes.allianceTicker}>[{character.alliance_ticker}]</span>}
          </div>
        </div>
      </div>
    </div>
  );
};
