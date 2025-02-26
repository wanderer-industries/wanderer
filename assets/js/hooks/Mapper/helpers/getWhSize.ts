import { SHIP_MASSES_SIZE } from '../components/map/constants';
import { ShipSizeStatus } from '../types/connection';
import { WormholeDataRaw } from '../types/wormholes';

export const getWhSize = (whDatas: WormholeDataRaw[], whType: string): ShipSizeStatus | null => {
  if (whType === 'K162' || whType == null) return null;

  const wormholeData = whDatas.find(wh => wh.name === whType);

  if (!wormholeData?.max_mass_per_jump) return null;

  return SHIP_MASSES_SIZE[wormholeData.max_mass_per_jump] ?? ShipSizeStatus.large;
};
