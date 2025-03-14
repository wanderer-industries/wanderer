import clsx from 'clsx';
import { WithClassName } from '@/hooks/Mapper/types/common.ts';

export enum CharacterPortraitSize {
  default,
  w18,
  w33,
}

// TODO IF YOU NEED ANOTHER ONE SIZE PLEASE ADD IT HERE and IN CharacterPortraitSize
const getSize = (size: CharacterPortraitSize) => {
  switch (size) {
    case CharacterPortraitSize.w18:
      return 'min-w-[18px] min-h-[18px] w-[18px] h-[18px]';
    case CharacterPortraitSize.w33:
      return 'min-w-[33px] min-h-[33px] w-[33px] h-[33px]';
    default:
      return '';
  }
};

export type CharacterPortraitProps = {
  characterEveId: string | undefined;
  size?: CharacterPortraitSize;
} & WithClassName;

export const CharacterPortrait = ({
  characterEveId,
  size = CharacterPortraitSize.default,
  className,
}: CharacterPortraitProps) => {
  if (characterEveId == null) {
    return null;
  }

  return (
    <span
      className={clsx(
        getSize(size),
        'flex transition-[border-color,opacity] duration-250 border border-gray-800 bg-transparent rounded-none',
        'wd-bg-default',
        className,
      )}
      style={{ backgroundImage: `url(https://images.evetech.net/characters/${characterEveId}/portrait)` }}
    />
  );
};
