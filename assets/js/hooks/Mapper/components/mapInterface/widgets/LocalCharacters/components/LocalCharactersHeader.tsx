import React, { useRef } from 'react';
import clsx from 'clsx';
import useMaxWidth from '@/hooks/Mapper/hooks/useMaxWidth';
import { LayoutEventBlocker, WdResponsiveCheckbox, WdDisplayMode } from '@/hooks/Mapper/components/ui-kit';
import { useElementWidth } from '@/hooks/Mapper/components/hooks';

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
  const headerWidth = useElementWidth(headerRef) || 300;

  const reservedWidth = 100;
  const availableWidthForCheckboxes = Math.max(headerWidth - reservedWidth, 0);

  let displayMode: WdDisplayMode = "full";
  if (availableWidthForCheckboxes >= 150) {
    displayMode = "full";
  } else if (availableWidthForCheckboxes >= 100) {
    displayMode = "abbr";
  } else {
    displayMode = "checkbox";
  }

  const compact = useMaxWidth(headerRef, 145);

  return (
    <div className="flex w-full items-center text-xs" ref={headerRef}>
      <div className="flex-shrink-0 select-none mr-2">
        Local{showList ? ` [${sortedCount}]` : ""}
      </div>
      <div className="flex-grow overflow-hidden">
        <LayoutEventBlocker className="flex items-center gap-2 justify-end">
          <div className="flex items-center gap-2">
            {showOffline && (
              <WdResponsiveCheckbox
                tooltipContent="Show offline characters in system"
                size="xs"
                labelFull="Show offline"
                labelAbbreviated="Offline"
                value={settings.showOffline}
                onChange={() =>
                  setSettings((prev: any) => ({ ...prev, showOffline: !prev.showOffline }))
                }
                classNameLabel={clsx("whitespace-nowrap text-stone-400 hover:text-stone-200 transition duration-300", { truncate: compact })}
                displayMode={displayMode}
              />
            )}
            {settings.compact && (
              <WdResponsiveCheckbox
                tooltipContent="Show ship name in compact rows"
                size="xs"
                labelFull="Show ship name"
                labelAbbreviated="Ship name"
                value={settings.showShipName}
                onChange={() =>
                  setSettings((prev: any) => ({ ...prev, showShipName: !prev.showShipName }))
                }
                classNameLabel={clsx("whitespace-nowrap text-stone-400 hover:text-stone-200 transition duration-300", { truncate: compact })}
                displayMode={displayMode}
              />
            )}
          </div>
          <span
            className={clsx("w-4 h-4 cursor-pointer", {
              "hero-bars-2": settings.compact,
              "hero-bars-3": !settings.compact,
            })}
            onClick={() => setSettings((prev: any) => ({ ...prev, compact: !prev.compact }))}
          />
        </LayoutEventBlocker>
      </div>
    </div>
  );
};
