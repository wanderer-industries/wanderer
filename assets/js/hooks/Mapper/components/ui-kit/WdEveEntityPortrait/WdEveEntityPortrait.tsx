import clsx from 'clsx';
import { WithClassName } from '@/hooks/Mapper/types/common.ts';

export enum WdEveEntityPortraitType {
  character,
  corporation,
  alliance,
  ship,
}

export enum WdEveEntityPortraitSize {
  default,
  w18,
  w33,
}

export const getLogo = (type: WdEveEntityPortraitType, eveId: string | number) => {
  switch (type) {
    case WdEveEntityPortraitType.alliance:
      return `url(https://images.evetech.net/alliances/${eveId}/logo?size=64)`;
    case WdEveEntityPortraitType.corporation:
      return `url(https://images.evetech.net/corporations/${eveId}/logo?size=64)`;
    case WdEveEntityPortraitType.character:
      return `url(https://images.evetech.net/characters/${eveId}/portrait)`;
    case WdEveEntityPortraitType.ship:
      return `url(https://images.evetech.net/types/${eveId}/icon)`;
  }

  return '';
};

// TODO IF YOU NEED ANOTHER ONE SIZE PLEASE ADD IT HERE and IN WdEveEntityPortraitSize
const getSize = (size: WdEveEntityPortraitSize) => {
  switch (size) {
    case WdEveEntityPortraitSize.w18:
      return 'min-w-[18px] min-h-[18px] w-[18px] h-[18px]';
    case WdEveEntityPortraitSize.w33:
      return 'min-w-[33px] min-h-[33px] w-[33px] h-[33px]';
    default:
      return '';
  }
};

export type WdEveEntityPortraitProps = {
  eveId: string | undefined;
  type?: WdEveEntityPortraitType;
  size?: WdEveEntityPortraitSize;
} & WithClassName;

export const WdEveEntityPortrait = ({
  eveId,
  size = WdEveEntityPortraitSize.default,
  type = WdEveEntityPortraitType.character,
  className,
}: WdEveEntityPortraitProps) => {
  if (eveId == null) {
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
      style={{ backgroundImage: getLogo(type, eveId) }}
    />
  );
};
