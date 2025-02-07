import React, { useRef } from 'react';
import clsx from 'clsx';
import {
  LayoutEventBlocker,
  WdResponsiveCheckbox,
  WdImgButton,
  TooltipPosition,
  WdDisplayMode,
} from '@/hooks/Mapper/components/ui-kit';
import { useKillsWidgetSettings } from '../hooks/useKillsWidgetSettings';
import { PrimeIcons } from 'primereact/api';
import { useElementWidth } from '@/hooks/Mapper/components/hooks';

interface KillsHeaderProps {
  systemId?: string;
  onOpenSettings: () => void;
}

export const KillsHeader: React.FC<KillsHeaderProps> = ({ systemId, onOpenSettings }) => {
  const [settings, setSettings] = useKillsWidgetSettings();
  const { showAll } = settings;

  const onToggleShowAllVisible = () => {
    setSettings(prev => ({ ...prev, showAll: !prev.showAll }));
  };

  const headerRef = useRef<HTMLDivElement>(null);
  const headerWidth = useElementWidth(headerRef) || 300;

  const reservedWidth = 100;
  const availableWidth = Math.max(headerWidth - reservedWidth, 0);

  let displayMode: WdDisplayMode = "full";
  if (availableWidth >= 60) {
    displayMode = "full";
  } else {
    displayMode = "abbr";
  }

  return (
    <div className="flex w-full items-center text-xs" ref={headerRef}>
      <div className="flex-shrink-0 select-none mr-2">
        Kills{systemId && !showAll && ' in '}
      </div>
      <div className="flex-grow overflow-hidden">
        <LayoutEventBlocker className="flex items-center gap-2 justify-end">
          <div className="flex items-center gap-2">
            <WdResponsiveCheckbox
              tooltipContent="Show all systems"
              size="xs"
              labelFull="Show all systems"
              labelAbbreviated="All"
              value={showAll}
              onChange={onToggleShowAllVisible}
              classNameLabel={clsx("whitespace-nowrap", "truncate")}
              displayMode={displayMode}
            />
            <WdImgButton
              className={PrimeIcons.SLIDERS_H}
              onClick={onOpenSettings}
              tooltip={{
                content: 'Open Kills Settings',
                position: TooltipPosition.left,
              }}
            />
          </div>
        </LayoutEventBlocker>
      </div>
    </div>
  );
};
