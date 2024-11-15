import { PrimeIcons } from 'primereact/api';
import { SignatureGroup, SystemSignature } from '@/hooks/Mapper/types';
import { SystemViewStandalone, WHClassView } from '@/hooks/Mapper/components/ui-kit';

import { WdTooltipWrapper } from '@/hooks/Mapper/components/ui-kit/WdTooltipWrapper';

import clsx from 'clsx';
import { renderName } from './renderName.tsx';
import classes from './renderInfoColumn.module.scss';

export const renderInfoColumn = (row: SystemSignature) => {
  if (!row.group || row.group === SignatureGroup.Wormhole) {
    return (
      <div className="flex justify-start items-center gap-[6px]">
        {row.type && (
          <WHClassView
            className="text-[11px]"
            classNameWh={classes.whFontSize}
            highlightName
            hideWhClass={!!row.linked_system}
            whClassName={row.type}
            noOffset
            useShortTitle
          />
        )}

        {row.linked_system && (
          <>
            {/*<span className="w-4 h-4 hero-arrow-long-right"></span>*/}
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
