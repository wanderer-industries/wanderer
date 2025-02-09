import React, { useRef } from 'react';
import clsx from 'clsx';
import useMaxWidth from '@/hooks/Mapper/hooks/useMaxWidth';
import { LayoutEventBlocker, TooltipPosition, WdCheckbox, WdTooltipWrapper } from '@/hooks/Mapper/components/ui-kit';

interface LocalCharactersHeaderProps {
  sortedCount: number;
  showList: boolean;
  showOffline: boolean;
  settings: {
    compact: boolean;
    showOffline: boolean;
    showShipName: boolean;
  };
  setSettings: (fn: (prev: any) => any) => void;
}

export const LocalCharactersHeader: React.FC<LocalCharactersHeaderProps> = ({
  sortedCount,
  showList,
  showOffline,
  settings,
  setSettings,
}) => {
  const headerRef = useRef<HTMLDivElement>(null);
  const compactOffline = useMaxWidth(headerRef, 145);
  const compactShipName = useMaxWidth(headerRef, 195);

  return (
    <div className="flex w-full items-center text-xs justify-between" ref={headerRef}>
      <div className="flex-shrink-0 select-none mr-2">Local{showList ? ` [${sortedCount}]` : ''}</div>
      <LayoutEventBlocker className="flex items-center gap-2 justify-end">
        <div className="flex items-center gap-2">
          {showOffline && (
            <WdTooltipWrapper content="Show offline characters in system" position={TooltipPosition.top}>
              <WdCheckbox
                size="xs"
                labelSide="left"
                label={compactOffline ? '' : 'Offline'}
                value={settings.showOffline}
                onChange={() => setSettings((prev: any) => ({ ...prev, showOffline: !prev.showOffline }))}
                classNameLabel={clsx('whitespace-nowrap text-stone-400 hover:text-stone-200 transition duration-300', {
                  truncate: compactOffline,
                })}
              />
            </WdTooltipWrapper>
          )}

          {settings.compact && (
            <WdTooltipWrapper content="Show ship name in compact rows" position={TooltipPosition.top}>
              <WdCheckbox
                size="xs"
                labelSide="left"
                label={compactShipName ? '' : 'Ship name'}
                value={settings.showShipName}
                onChange={() => setSettings((prev: any) => ({ ...prev, showShipName: !prev.showShipName }))}
                classNameLabel={clsx('whitespace-nowrap text-stone-400 hover:text-stone-200 transition duration-300', {
                  truncate: compactShipName,
                })}
              />
            </WdTooltipWrapper>
          )}
        </div>
        <WdTooltipWrapper content="Enable compact mode" position={TooltipPosition.top}>
          <span
            className={clsx('w-4 h-4 min-w-[1rem] cursor-pointer', {
              'hero-bars-2': settings.compact,
              'hero-bars-3': !settings.compact,
            })}
            onClick={() => setSettings((prev: any) => ({ ...prev, compact: !prev.compact }))}
          />
        </WdTooltipWrapper>
      </LayoutEventBlocker>
    </div>
  );
};
