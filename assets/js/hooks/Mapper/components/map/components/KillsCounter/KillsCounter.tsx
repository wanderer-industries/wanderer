import { useMemo } from 'react';
import { useKillsCounter } from '../../hooks/useKillsCounter.ts';
import { WdTooltipWrapper } from '@/hooks/Mapper/components/ui-kit/WdTooltipWrapper';
import { WithChildren, WithClassName } from '@/hooks/Mapper/types/common.ts';
import {
  KILLS_ROW_HEIGHT,
  SystemKillsList,
} from '@/hooks/Mapper/components/mapInterface/widgets/WSystemKills/SystemKillsList';
import { TooltipSize } from '@/hooks/Mapper/components/ui-kit/WdTooltipWrapper/utils.ts';

const MIN_TOOLTIP_HEIGHT = 40;

type KillsBookmarkTooltipProps = {
  killsCount: number;
  killsActivityType: string | null;
  systemId: string;
  className?: string;
  size?: TooltipSize;
} & WithChildren &
  WithClassName;

export const KillsCounter = ({
  killsCount,
  systemId,
  className,
  children,
  size = TooltipSize.xs,
}: KillsBookmarkTooltipProps) => {
  const { isLoading, kills: detailedKills } = useKillsCounter({
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
  const killsNeededHeight = limitedKills.length * KILLS_ROW_HEIGHT;
  // Add a small buffer (10px) to prevent scrollbar from appearing unnecessarily
  const tooltipHeight = Math.max(MIN_TOOLTIP_HEIGHT, Math.min(killsNeededHeight + 10, 500));

  return (
    <WdTooltipWrapper
      content={
        <div className="overflow-hidden flex w-[450px] flex-col" style={{ height: `${tooltipHeight}px` }}>
          <div className="flex-1 h-full">
            <SystemKillsList kills={limitedKills} onlyOneSystem timeRange={1} />
          </div>
        </div>
      }
      className={className}
      tooltipClassName="!px-0"
      size={size}
      interactive
      smallPaddings
    >
      {children}
    </WdTooltipWrapper>
  );
};
