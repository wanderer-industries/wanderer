import React from 'react';
import clsx from 'clsx';
import {
  LayoutEventBlocker,
  WdImgButton,
  WdCheckbox,
  TooltipPosition,
  SystemView,
} from '@/hooks/Mapper/components/ui-kit';
import { useKillsWidgetSettings } from '../hooks/useKillsWidgetSettings';

interface KillsWidgetHeaderProps {
  systemId?: string;
}

export const KillsHeader: React.FC<KillsWidgetHeaderProps> = ({ systemId }) => {
  const [settings, setSettings] = useKillsWidgetSettings();
  const { showAllVisible, compact } = settings;

  // toggles
  const onToggleShowAllVisible = () => {
    setSettings(prev => ({ ...prev, showAllVisible: !prev.showAllVisible }));
  };
  const onToggleCompact = () => {
    setSettings(prev => ({ ...prev, compact: !prev.compact }));
  };

  return (
    <div className="flex justify-between items-center text-xs w-full">
      <div className="flex items-center gap-1">
        <div className="text-stone-400">
          Kills
          {systemId && !showAllVisible && ' in '}
        </div>
        {systemId && !showAllVisible && (
          <SystemView systemId={systemId} className="select-none text-center" hideRegion />
        )}
      </div>

      <LayoutEventBlocker className="flex gap-2 items-center">
        <WdCheckbox
          size="xs"
          labelSide="left"
          label="Show all systems"
          value={showAllVisible}
          classNameLabel="text-stone-400 hover:text-stone-200 transition duration-300"
          onChange={onToggleShowAllVisible}
        />

        <WdImgButton
          className={clsx(
            compact ? 'hero-bars-2' : 'hero-bars-3',
            'hover:text-sky-200 transition duration-300',
            'inline-flex items-center justify-center w-5 h-5 text-sm leading-none align-middle',
          )}
          onClick={onToggleCompact}
          tooltip={{
            content: 'Toggle compact mode',
            position: TooltipPosition.left,
          }}
        />
      </LayoutEventBlocker>
    </div>
  );
};
