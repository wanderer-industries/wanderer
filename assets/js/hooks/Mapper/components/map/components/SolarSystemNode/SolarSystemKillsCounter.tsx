import { SystemKillsContent } from '../../../mapInterface/widgets/SystemKills/SystemKillsContent/SystemKillsContent';
import { useKillsCounter } from '../../hooks/useKillsCounter';
import { WdTooltipWrapper } from '@/hooks/Mapper/components/ui-kit/WdTooltipWrapper';
import { WithChildren, WithClassName } from '@/hooks/Mapper/types/common';

type TooltipSize = 'xs' | 'sm' | 'md' | 'lg';

type KillsBookmarkTooltipProps = {
  killsCount: number;
  killsActivityType: string | null;
  systemId: string;
  className?: string;
  size?: TooltipSize;
  timeRange?: number;
} & WithChildren &
  WithClassName;

export const KillsCounter = ({
  killsCount,
  systemId,
  className,
  children,
  size = 'xs',
  timeRange = 1,
}: KillsBookmarkTooltipProps) => {
  const { isLoading, kills: detailedKills, systemNameMap } = useKillsCounter({ realSystemId: systemId });

  if (!killsCount || detailedKills.length === 0 || !systemId || isLoading) return null;

  const tooltipContent = (
    <SystemKillsContent
      kills={detailedKills}
      systemNameMap={systemNameMap}
      compact={true}
      onlyOneSystem={true}
      autoSize={true}
      timeRange={timeRange}
      limit={killsCount}
    />
  );

  return (
    // @ts-ignore
    <WdTooltipWrapper content={tooltipContent} className={className} size={size} interactive={true}>
      {children}
    </WdTooltipWrapper>
  );
};
