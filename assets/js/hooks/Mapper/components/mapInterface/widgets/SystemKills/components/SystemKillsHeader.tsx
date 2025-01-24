import React from 'react';
import {
  LayoutEventBlocker,
  WdCheckbox,
  WdImgButton,
  TooltipPosition,
  SystemView,
} from '@/hooks/Mapper/components/ui-kit';
import { useKillsWidgetSettings } from '../hooks/useKillsWidgetSettings';
import { PrimeIcons } from 'primereact/api';

interface KillsWidgetHeaderProps {
  systemId?: string;
  onOpenSettings: () => void;
}

export const KillsHeader: React.FC<KillsWidgetHeaderProps> = ({ systemId, onOpenSettings }) => {
  const [settings, setSettings] = useKillsWidgetSettings();
  const { showAll } = settings;

  const onToggleShowAllVisible = () => {
    setSettings(prev => ({ ...prev, showAll: !prev.showAll }));
  };

  return (
    <div className="flex justify-between items-center text-xs w-full">
      <div className="flex items-center gap-1">
        <div className="text-stone-400">
          Kills
          {systemId && !showAll && ' in '}
        </div>
        {systemId && !showAll && <SystemView systemId={systemId} className="select-none text-center" hideRegion />}
      </div>

      <LayoutEventBlocker className="flex gap-2 items-center">
        <WdCheckbox
          size="xs"
          labelSide="left"
          label="Show all systems"
          value={showAll}
          classNameLabel="text-stone-400 hover:text-stone-200 transition duration-300"
          onChange={onToggleShowAllVisible}
        />

        <WdImgButton
          className={PrimeIcons.SLIDERS_H}
          onClick={onOpenSettings}
          tooltip={{
            content: 'Open Kills Settings',
            position: TooltipPosition.left,
          }}
        />
      </LayoutEventBlocker>
    </div>
  );
};
