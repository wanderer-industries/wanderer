import { WdTooltipWrapper } from '@/hooks/Mapper/components/ui-kit/WdTooltipWrapper';
import { InfoDrawer } from '@/hooks/Mapper/components/ui-kit';

import classes from './UnsplashedSignature.module.scss';
import { SystemSignature } from '@/hooks/Mapper/types/signatures';
import { useMapRootState } from '@/hooks/Mapper/mapRootProvider';
import { WORMHOLE_CLASS_STYLES, WORMHOLES_ADDITIONAL_INFO } from '@/hooks/Mapper/components/map/constants.ts';
import { useMemo } from 'react';
import clsx from 'clsx';
import { renderInfoColumn } from '@/hooks/Mapper/components/mapInterface/widgets/SystemSignatures/renders';
import { K162_TYPES_MAP } from '@/hooks/Mapper/constants.ts';
import { parseSignatureCustomInfo } from '@/hooks/Mapper/helpers/parseSignatureCustomInfo.ts';

interface UnsplashedSignatureProps {
  signature: SystemSignature;
}
export const UnsplashedSignature = ({ signature }: UnsplashedSignatureProps) => {
  const {
    data: { wormholesData },
  } = useMapRootState();

  const whData = useMemo(() => wormholesData[signature.type], [signature.type, wormholesData]);
  const whClass = useMemo(() => (whData ? WORMHOLES_ADDITIONAL_INFO[whData.dest] : null), [whData]);

  const k162TypeOption = useMemo(() => {
    const customInfo = parseSignatureCustomInfo(signature.custom_info);
    if (!customInfo?.k162Type) {
      return null;
    }

    return K162_TYPES_MAP[customInfo.k162Type];
  }, [signature]);

  const whClassStyle = useMemo(() => {
    if (signature.type === 'K162' && k162TypeOption) {
      const k162Data = wormholesData[k162TypeOption.whClassName];
      const k162Class = k162Data ? WORMHOLES_ADDITIONAL_INFO[k162Data.dest] : null;
      return k162Class ? WORMHOLE_CLASS_STYLES[k162Class.wormholeClassID] : '';
    }
    return whClass ? WORMHOLE_CLASS_STYLES[whClass.wormholeClassID] : '';
  }, [signature, whClass, k162TypeOption, wormholesData]);

  return (
    <WdTooltipWrapper
      className={clsx(classes.Signature)}
      // @ts-ignore
      content={
        <div className="flex flex-col gap-1">
          <InfoDrawer title={<b className="text-slate-50">{signature.eve_id}</b>}>
            {renderInfoColumn(signature)}
          </InfoDrawer>
        </div>
      }
    >
      <div className={clsx(classes.Box, whClassStyle)}>
        <svg width="13" height="4" viewBox="0 0 13 4" xmlns="http://www.w3.org/2000/svg">
          <rect width="13" height="4" rx="2" className={whClassStyle} fill="currentColor" />
        </svg>
      </div>
    </WdTooltipWrapper>
  );
};
