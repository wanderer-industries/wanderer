import React from 'react';
import {
  LayoutEventBlocker,
  WdImgButton,
  TooltipPosition,
  InfoDrawer,
  SystemView,
} from '@/hooks/Mapper/components/ui-kit';
import { PrimeIcons } from 'primereact/api';

interface KillsWidgetHeaderProps {
  systemId?: string;
  showAllVisible: boolean;
  onToggleShowAllVisible: () => void;
}

export const KillsHeader: React.FC<KillsWidgetHeaderProps> = ({ systemId, showAllVisible, onToggleShowAllVisible }) => {
  return (
    <div className="flex justify-between items-center text-xs w-full h-full">
      <div className="flex items-center gap-1">
        <div className="text-stone-400">
          Kills
          {systemId && !showAllVisible && ' in '}
        </div>
        {systemId && !showAllVisible && (
          <SystemView systemId={systemId} className="select-none text-center" hideRegion />
        )}
      </div>

      <LayoutEventBlocker className="flex gap-2">
        <WdImgButton
          className={`
                ${showAllVisible ? `${PrimeIcons.EYE} text-sky-400` : `${PrimeIcons.EYE_SLASH} text-gray-400`}
                hover:text-sky-200
                transition
                duration-300
              `}
          onClick={onToggleShowAllVisible}
          tooltip={{
            content: showAllVisible ? 'All visible systems' : 'Selected system',
            position: TooltipPosition.left,
          }}
        />

        <WdImgButton
          className={PrimeIcons.QUESTION_CIRCLE}
          tooltip={{
            position: TooltipPosition.left,
            // @ts-ignore
            content: (
              <InfoDrawer title={<b className="text-slate-50">What am I looking at?</b>}>
                These are killmails from the last 24 hours for the selected system,
                <br />
                or for all visible systems if that mode is toggled on.
              </InfoDrawer>
            ),
          }}
        />
      </LayoutEventBlocker>
    </div>
  );
};
