import { SystemKillsContent } from '../../../mapInterface/widgets/SystemKills/SystemKillsContent/SystemKillsContent';
import { useKillsCounter } from '../../hooks/useKillsCounter';
import { WdTooltipWrapper } from '@/hooks/Mapper/components/ui-kit/WdTooltipWrapper';
import { WithChildren, WithClassName } from '@/hooks/Mapper/types/common';
import { useMemo } from 'react';

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
  const { isLoading, kills: detailedKills, systemNameMap } = useKillsCounter({ realSystemId: systemId });

  // Limit the kills shown to match the killsCount parameter
  const limitedKills = useMemo(() => {
    if (!detailedKills || detailedKills.length === 0) return [];
    return detailedKills.slice(0, killsCount);
  }, [detailedKills, killsCount]);

  if (!killsCount || limitedKills.length === 0 || !systemId || isLoading) return null;

  // Calculate a reasonable height for the tooltip based on the number of kills
  // but cap it to avoid excessively large tooltips
  const maxKillsToShow = Math.min(limitedKills.length, 20);
  const tooltipHeight = Math.max(200, Math.min(500, maxKillsToShow * 35));

  const tooltipContent = (
    <div
      style={{
        width: '400px',
        height: `${tooltipHeight}px`,
        maxHeight: '500px',
        overflow: 'hidden',
        display: 'flex',
        flexDirection: 'column',
      }}
    >
      <div className="p-2 border-b border-stone-700 bg-stone-800 text-stone-200 font-medium">
        System Kills ({limitedKills.length})
      </div>
      <div className="flex-1 overflow-hidden">
        <SystemKillsContent
          kills={limitedKills}
          systemNameMap={systemNameMap}
          onlyOneSystem={true}
          // Don't use autoSize here as we want the virtual scroller to handle scrolling
          autoSize={false}
          // We've already limited the kills to match killsCount
          limit={undefined}
        />
      </div>
    </div>
  );

  return (
    <WdTooltipWrapper content={tooltipContent} className={className} size={size} interactive={true}>
      {children}
    </WdTooltipWrapper>
  );
};
