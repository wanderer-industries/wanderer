import { DotlanBehavior } from '@/hooks/Mapper/mapRootProvider/types.ts';

export interface GetDotlanUrlParams {
  behavior: DotlanBehavior;
  isWormhole: boolean;
  regionName: string;
  systemName: string;
}

export const getDotlanUrl = ({ behavior, isWormhole, regionName, systemName }: GetDotlanUrlParams) => {
  if (isWormhole || behavior === DotlanBehavior.system) {
    return `https://evemaps.dotlan.net/system/${systemName}`;
  }

  const formattedRegionName = regionName.replace(/ /g, '_');
  return `https://evemaps.dotlan.net/map/${formattedRegionName}/${systemName}#${behavior}`;
};
