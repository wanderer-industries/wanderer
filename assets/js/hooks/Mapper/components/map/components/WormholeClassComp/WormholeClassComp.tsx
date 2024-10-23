import { useMapState } from '@/hooks/Mapper/components/map/MapProvider.tsx';
import { WORMHOLE_CLASS_STYLES, WORMHOLES_ADDITIONAL_INFO } from '@/hooks/Mapper/components/map/constants.ts';
import clsx from 'clsx';

interface WormholeClassComp {
  id: string;
}
export const WormholeClassComp = ({ id }: WormholeClassComp) => {
  const {
    data: { wormholesData },
  } = useMapState();

  const wormholeData = wormholesData[id];
  const wormholeDataAdditional = WORMHOLES_ADDITIONAL_INFO[wormholeData.dest];

  if (!wormholeData || !wormholeDataAdditional) {
    return null;
  }

  const colorClass = WORMHOLE_CLASS_STYLES[wormholeDataAdditional.wormholeClassID.toString()];
  return (
    <div className={clsx(colorClass, '[text-shadow:_0_1px_0_rgb(0_0_0_/_40%)]')}>
      {wormholeDataAdditional.shortName}
    </div>
  );
};
