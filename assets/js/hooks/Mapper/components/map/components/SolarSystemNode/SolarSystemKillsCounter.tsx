import React, { useMemo } from 'react';
import { SystemKillsContent } from '../../../mapInterface/widgets/SystemKills/SystemKillsContent/SystemKillsContent';
import { useKillsCounter } from '../../hooks/useKillsCounter';
import { WdTooltipWrapper } from '@/hooks/Mapper/components/ui-kit/WdTooltipWrapper';
import { WithChildren, WithClassName } from '@/hooks/Mapper/types/common';

const ITEM_HEIGHT = 35;
const MIN_TOOLTIP_HEIGHT = 40;

type TooltipSize = 'xs' | 'sm' | 'md' | 'lg';

type KillsBookmarkTooltipProps = {
  killsCount: number;
  killsActivityType: string | null;
  systemId: string;
  className?: string;
  size?: TooltipSize;
} & WithChildren &
  WithClassName;

export const KillsCounter = ({ killsCount, systemId, className, children, size = 'xs' }: KillsBookmarkTooltipProps) => {
  const {
    isLoading,
    kills: detailedKills,
    systemNameMap,
  } = useKillsCounter({
    realSystemId: systemId,
  });

  const limitedKills = useMemo(() => {
    if (!detailedKills || detailedKills.length === 0) return [];
    return detailedKills.slice(0, killsCount);
  }, [detailedKills, killsCount]);

  if (!killsCount || limitedKills.length === 0 || !systemId || isLoading) {
    return null;
  }

  // Calculate height based on number of kills, but ensure a minimum height
  const killsNeededHeight = limitedKills.length * ITEM_HEIGHT;
  // Add a small buffer (10px) to prevent scrollbar from appearing unnecessarily
  const tooltipHeight = Math.max(MIN_TOOLTIP_HEIGHT, Math.min(killsNeededHeight + 10, 500));

  const tooltipContent = (
    <div
      style={{
        width: '400px',
        height: `${tooltipHeight}px`,
        display: 'flex',
        flexDirection: 'column',
      }}
      className="overflow-hidden"
    >
      <div className="flex-1 h-full">
        <SystemKillsContent kills={limitedKills} systemNameMap={systemNameMap} onlyOneSystem />
      </div>
    </div>
  );

  return (
    <WdTooltipWrapper content={tooltipContent} className={className} size={size} interactive={true}>
      {children}
    </WdTooltipWrapper>
  );
};
