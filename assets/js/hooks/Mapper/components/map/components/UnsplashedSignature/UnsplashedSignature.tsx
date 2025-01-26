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

  const customInfo = useMemo(() => {
    return parseSignatureCustomInfo(signature.custom_info);
  }, [signature]);

  const k162TypeOption = useMemo(() => {
    if (!customInfo?.k162Type) {
      return null;
    }

    return K162_TYPES_MAP[customInfo.k162Type];
  }, [customInfo]);

  const isEOL = useMemo(() => {
    return customInfo?.isEOL;
  }, [customInfo]);

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
        <svg width="13" height="8" viewBox="0 0 13 8" xmlns="http://www.w3.org/2000/svg">
          <rect y="1" width="13" height="4" rx="2" className={whClassStyle} fill="currentColor" />
          {isEOL && <rect x="4" width="5" height="6" rx="1" className={clsx(classes.Eol)} fill="#a153ac" />}
        </svg>
      </div>
    </WdTooltipWrapper>
  );
};
