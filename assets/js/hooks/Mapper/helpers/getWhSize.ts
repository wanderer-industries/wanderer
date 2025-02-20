import { ShipSizeStatus } from '../types/connection';
import { WormholeDataRaw } from '../types/wormholes';

const SIZE_CLASSES = [
  { threshold: 5_000_000, status: ShipSizeStatus.small },
  { threshold: 62_000_000, status: ShipSizeStatus.medium },
  { threshold: 375_000_000, status: ShipSizeStatus.large },
  { threshold: 1_000_000_000, status: ShipSizeStatus.freight },
  { threshold: 2_000_000_000, status: ShipSizeStatus.capital },
];

export const getWhSize = (whDatas: WormholeDataRaw[], whType: string): ShipSizeStatus | null => {
  if (whType === 'K162' || whType == null) return null;

  const wormholeData = whDatas.find(wh => wh.name === whType);

  if (!wormholeData?.max_mass_per_jump) return null;

  for (const sizeClass of SIZE_CLASSES) {
    if (wormholeData.max_mass_per_jump <= sizeClass.threshold) {
      return sizeClass.status;
    }
  }

  return ShipSizeStatus.large;
};
