import React from 'react';
import { LayoutEventBlocker, WdImgButton, TooltipPosition, SystemView } from '@/hooks/Mapper/components/ui-kit';
import { PrimeIcons } from 'primereact/api';
import clsx from 'clsx';

interface KillsWidgetHeaderProps {
  systemId?: string;
  showAllVisible: boolean;
  onToggleShowAllVisible: () => void;
  compact: boolean;
  onToggleCompact: () => void;
}

export const KillsHeader: React.FC<KillsWidgetHeaderProps> = ({
  systemId,
  showAllVisible,
  onToggleShowAllVisible,
  compact,
  onToggleCompact,
}) => {
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
        <WdImgButton
          className={clsx(
            showAllVisible ? `${PrimeIcons.EYE} text-sky-400` : `${PrimeIcons.EYE_SLASH} text-gray-400`,
            'hover:text-sky-200 transition duration-300',
            'inline-flex items-center justify-center w-5 h-5 text-sm leading-none align-middle',
          )}
          onClick={onToggleShowAllVisible}
          tooltip={{
            content: showAllVisible ? 'All visible systems' : 'Selected system',
            position: TooltipPosition.left,
          }}
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
