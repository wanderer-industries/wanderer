import { TrackingCharacter } from './types';
import { WdCheckbox } from '@/hooks/Mapper/components/ui-kit/WdCheckbox/WdCheckbox';
import WdRadioButton from '@/hooks/Mapper/components/ui-kit/WdRadioButton';
import { TooltipPosition, WdTooltipWrapper } from '../../../ui-kit';
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
    <div
      className={`
        grid grid-cols-[80px_80px_1fr]
        ${classes.characterRow}
        p-0.5 items-center transition-colors duration-200 min-h-8 hover:bg-surface-hover
      `}
    >
      <div className="flex justify-center items-center p-0.5 text-center">
        <WdTooltipWrapper content="Track this character on the map" position={TooltipPosition.top}>
          <div className="flex justify-center items-center w-full">
            <WdCheckbox id={trackCheckboxId} label="" value={isTracked} onChange={() => onTrackToggle()} />
          </div>
        </WdTooltipWrapper>
      </div>
      <div className="flex justify-center items-center p-0.5 text-center">
        <WdTooltipWrapper content="Follow this character's movements on the map" position={TooltipPosition.top}>
          <div className="flex justify-center items-center w-full">
            <div onClick={onFollowToggle} className="cursor-pointer">
              <WdRadioButton id={followRadioId} name="followed_character" checked={isFollowed} onChange={() => {}} />
            </div>
          </div>
        </WdTooltipWrapper>
      </div>
      <div className="p-0.5 flex items-center justify-center">
        <div className="flex items-center gap-3 w-full overflow-hidden min-h-8 justify-center">
          <div className="w-8 h-8 rounded-full overflow-hidden flex-shrink-0">
            <img src={character.portrait_url} alt={character.name} className="w-full h-full object-cover" />
          </div>
          <div className="flex items-center overflow-hidden flex-nowrap whitespace-nowrap">
            <span
              className={`
                text-sm text-color-color whitespace-nowrap overflow-hidden text-ellipsis max-w-[150px]
              `}
            >
              {character.name}
            </span>
            <span className="ml-2 text-text-color-secondary text-sm">[{character.corporation_ticker}]</span>
            {character.alliance_ticker && (
              <span className="ml-1 text-text-color-secondary text-sm">[{character.alliance_ticker}]</span>
            )}
          </div>
        </div>
      </div>
    </div>
  );
};
