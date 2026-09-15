import { LayoutEventBlocker, TooltipPosition, WdImageSize, WdImgButton } from '@/hooks/Mapper/components/ui-kit';
import { ANOIK_ICON, DOTLAN_ICON, ZKB_ICON } from '@/hooks/Mapper/icons';
import { getDotlanUrl } from '@/hooks/Mapper/helpers/getDotlanUrl.ts';
import { useMapRootState } from '@/hooks/Mapper/mapRootProvider';
import { DotlanBehavior } from '@/hooks/Mapper/mapRootProvider/types.ts';
import { useCallback, useRef } from 'react';

import clsx from 'clsx';
import { PrimeIcons } from 'primereact/api';
import classes from './FastSystemActions.module.scss';

export interface FastSystemActionsProps {
  systemId: string;
  systemName: string;
  regionName: string;
  isWH: boolean;
  showEdit?: boolean;
  onOpenSettings(): void;
}

export const FastSystemActions = ({
  systemId,
  systemName,
  regionName,
  isWH,
  onOpenSettings,
  showEdit,
}: FastSystemActionsProps) => {
  const {
    storedSettings: { interfaceSettings },
  } = useMapRootState();
  const dotlanBehavior = interfaceSettings.dotlanBehavior ?? DotlanBehavior.system;

  const ref = useRef({ systemId, systemName, regionName, isWH, dotlanBehavior });
  ref.current = { systemId, systemName, regionName, isWH, dotlanBehavior };

  const handleOpenZKB = useCallback(
    () => window.open(`https://zkillboard.com/system/${ref.current.systemId}/`, '_blank'),
    [],
  );

  const handleOpenAnoikis = useCallback(
    () => window.open(`http://anoik.is/systems/${ref.current.systemName}`, '_blank'),
    [],
  );

  const handleOpenDotlan = useCallback(() => {
    const { dotlanBehavior, isWH, regionName, systemName } = ref.current;
    const url = getDotlanUrl({ behavior: dotlanBehavior, isWormhole: isWH, regionName, systemName });
    return window.open(url, '_blank');
  }, []);

  const copySystemNameToClipboard = useCallback(async () => {
    try {
      await navigator.clipboard.writeText(ref.current.systemName);
    } catch (err) {
      console.error(err);
    }
  }, []);

  return (
    <LayoutEventBlocker className={clsx('flex px-2 gap-2 justify-between items-center h-full')}>
      <div className={clsx('flex gap-2 items-center h-full', classes.Links)}>
        <WdImgButton
          tooltip={{ position: TooltipPosition.top, content: 'Open zkillboard' }}
          source={ZKB_ICON}
          onClick={handleOpenZKB}
        />
        <WdImgButton
          tooltip={{ position: TooltipPosition.top, content: 'Open Anoikis' }}
          source={ANOIK_ICON}
          onClick={handleOpenAnoikis}
        />
        <WdImgButton
          tooltip={{ position: TooltipPosition.top, content: 'Open Dotlan' }}
          source={DOTLAN_ICON}
          onClick={handleOpenDotlan}
        />
      </div>

      <div className="flex gap-2 items-center pl-1">
        <WdImgButton
          textSize={WdImageSize.off}
          className={PrimeIcons.COPY}
          onClick={copySystemNameToClipboard}
          tooltip={{ position: TooltipPosition.top, content: 'Copy system name' }}
        />
        {showEdit && (
          <WdImgButton
            textSize={WdImageSize.off}
            className="pi pi-pen-to-square text-base"
            onClick={onOpenSettings}
            tooltip={{ position: TooltipPosition.top, content: 'Edit system name and description' }}
          />
        )}
      </div>
    </LayoutEventBlocker>
  );
};
