import { SystemViewStandalone, TooltipPosition, WHClassView } from '@/hooks/Mapper/components/ui-kit';
import { SignatureGroup, SystemSignature, TimeStatus } from '@/hooks/Mapper/types';
import { PrimeIcons } from 'primereact/api';

import { renderK162Type } from '@/hooks/Mapper/components/mapRootContent/components/SignatureSettings/components/SignatureK162TypeSelect';
import { WdTooltipWrapper } from '@/hooks/Mapper/components/ui-kit/WdTooltipWrapper';

import { K162_TYPES_MAP } from '@/hooks/Mapper/constants.ts';
import { parseSignatureCustomInfo } from '@/hooks/Mapper/helpers/parseSignatureCustomInfo.ts';
import clsx from 'clsx';
import { renderName } from './renderName.tsx';

export const renderInfoColumn = (row: SystemSignature) => {
  if (!row.group || row.group === SignatureGroup.Wormhole) {
    const customInfo = parseSignatureCustomInfo(row.custom_info);

    const k162TypeOption = customInfo.k162Type ? K162_TYPES_MAP[customInfo.k162Type] : null;

    return (
      <div className="flex justify-start items-center gap-[4px]">
        {row.temporary_name && <span className={clsx('text-[12px]')}>{row.temporary_name}</span>}

        {customInfo.time_status === TimeStatus._1h && (
          <WdTooltipWrapper offset={5} position={TooltipPosition.top} content="Signature marked as EOL">
            <div className="pi pi-clock text-fuchsia-400 text-[11px] mr-[2px]"></div>
          </WdTooltipWrapper>
        )}

        {customInfo.isCrit && (
          <WdTooltipWrapper offset={5} position={TooltipPosition.top} content="Signature marked as Crit">
            <div className="pi pi-clock text-fuchsia-400 text-[11px] mr-[2px]"></div>
          </WdTooltipWrapper>
        )}

        {row.type && (
          <WHClassView
            className="text-[11px]"
            classNameWh="!text-[11px] !font-bold"
            hideWhClass={!!row.linked_system}
            whClassName={row.type}
            noOffset
            useShortTitle
          />
        )}

        {!row.linked_system && row.type === 'K162' && k162TypeOption && renderK162Type(k162TypeOption)}

        {row.linked_system && (
          <>
            <span title={row.linked_system?.solar_system_name}>
              <SystemViewStandalone
                className={clsx('select-none text-center cursor-context-menu')}
                hideRegion
                {...row.linked_system}
              />
            </span>
          </>
        )}
        {row.description && (
          <WdTooltipWrapper content={row.description}>
            <span className={clsx(PrimeIcons.EXCLAMATION_CIRCLE, 'text-[12px]')}></span>
          </WdTooltipWrapper>
        )}
      </div>
    );
  }

  return (
    <div className="flex gap-1 items-center">
      {renderName(row)}{' '}
      {row.description && (
        <WdTooltipWrapper content={row.description}>
          <span className={clsx(PrimeIcons.EXCLAMATION_CIRCLE, 'text-[12px]')}></span>
        </WdTooltipWrapper>
      )}
    </div>
  );
};
