import React, { useRef } from 'react';
import {
  LayoutEventBlocker,
  SystemView,
  TooltipPosition,
  WdCheckbox,
  WdImgButton,
  WdTooltipWrapper,
} from '@/hooks/Mapper/components/ui-kit';
import { PrimeIcons } from 'primereact/api';
import useMaxWidth from '@/hooks/Mapper/hooks/useMaxWidth.ts';
import { useMapRootState } from '@/hooks/Mapper/mapRootProvider';

interface KillsHeaderProps {
  systemId?: string;
  onOpenSettings: () => void;
}

export const KillsHeader: React.FC<KillsHeaderProps> = ({ systemId, onOpenSettings }) => {
  const {
    storedSettings: { settingsKills, settingsKillsUpdate },
  } = useMapRootState();

  const { showAll } = settingsKills;

  const onToggleShowAllVisible = () => {
    settingsKillsUpdate(prev => ({ ...prev, showAll: !prev.showAll }));
  };

  const headerRef = useRef<HTMLDivElement>(null);
  const compact = useMaxWidth(headerRef, 150);

  return (
    <div className="flex w-full items-center justify-between text-xs" ref={headerRef}>
      <div className="flex items-center gap-1">
        <div className="text-stone-400">
          Kills
          {systemId && !showAll && ' in '}
        </div>
        {systemId && !showAll && <SystemView systemId={systemId} className="select-none text-center" hideRegion />}
      </div>

      <LayoutEventBlocker className="flex items-center gap-2 justify-end">
        <div className="flex items-center gap-2">
          <WdTooltipWrapper content="Show all systems" position={TooltipPosition.top}>
            <WdCheckbox
              size="xs"
              labelSide="left"
              label={compact ? 'All' : 'Show all systems'}
              value={showAll}
              onChange={onToggleShowAllVisible}
              classNameLabel="whitespace-nowrap text-stone-400 hover:text-stone-200 transition duration-300"
            />
          </WdTooltipWrapper>

          <WdImgButton
            className={PrimeIcons.SLIDERS_H}
            onClick={onOpenSettings}
            tooltip={{
              content: 'Open Kills Settings',
              position: TooltipPosition.top,
            }}
          />
        </div>
      </LayoutEventBlocker>
    </div>
  );
};
