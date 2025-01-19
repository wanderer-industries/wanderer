import { SystemKillsContent } from '../../../mapInterface/widgets/SystemKills/SystemKillsContent/SystemKillsContent';
import { useKillsCounter } from '../../hooks/useKillsCounter';
import { WdTooltipWrapper } from '@/hooks/Mapper/components/ui-kit/WdTooltipWrapper';
import { WithChildren, WithClassName } from '@/hooks/Mapper/types/common.ts';

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

  if (!killsCount || !systemId) return null;

  const tooltipContent = isLoading ? (
    <div className="w-full h-full flex justify-center items-center select-none text-center text-stone-400/80 text-sm">
      Loading kills
    </div>
  ) : (
    <SystemKillsContent kills={detailedKills} systemNameMap={systemNameMap} compact={true} onlyOneSystem={true} />
  );

  return (
    // @ts-ignore
    <WdTooltipWrapper content={tooltipContent} className={className} size={size}>
      {children}
    </WdTooltipWrapper>
  );
};
