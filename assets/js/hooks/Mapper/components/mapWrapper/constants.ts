import { MiniMapPlacement } from '@/hooks/Mapper/mapRootProvider/types.ts';

export const MINI_MAP_PLACEMENT_OFFSETS = {
  [MiniMapPlacement.rightTop]: { default: '!top-[48px]', withLeftMenu: '!top-[48px] !right-[58px]' },
  [MiniMapPlacement.rightBottom]: { default: '!bottom-[0px]', withLeftMenu: '!bottom-[0px] !right-[58px]' },
  [MiniMapPlacement.leftTop]: { default: '!top-[48px] !left-[56px]', withLeftMenu: '!top-[48px] !left-[56px]' },
  [MiniMapPlacement.leftBottom]: { default: '!left-[56px] !bottom-[0px]', withLeftMenu: '!left-[56px] !bottom-[0px]' },
};
