import { SystemKillsContent } from '../../../mapInterface/widgets/SystemKills/SystemKillsContent/SystemKillsContent';
import { useKillsCounter } from '../../hooks/useKillsCounter';
import { WdTooltipWrapper } from '@/hooks/Mapper/components/ui-kit/WdTooltipWrapper';
import { WithChildren, WithClassName } from '@/hooks/Mapper/types/common.ts';

type KillsBookmarkTooltipProps = {
  killsCount: number;
  killsActivityType: string | null;
  systemId: string;
  className?: string;
} & WithChildren &
  WithClassName;

export const KillsCounter = ({ killsCount, systemId, className, children }: KillsBookmarkTooltipProps) => {
  const { isLoading, kills: detailedKills, systemNameMap } = useKillsCounter({ realSystemId: systemId });

  if (!killsCount || !systemId) return null;

  const tooltipContent = isLoading ? (
    <div className="w-full h-full flex justify-center items-center select-none text-center text-stone-400/80 text-sm">
      Loading kills
    </div>
  ) : (
    <SystemKillsContent kills={detailedKills} systemNameMap={systemNameMap} compact={true} />
  );

  return (
    <WdTooltipWrapper content={tooltipContent} className={className}>
      {children}
    </WdTooltipWrapper>
  );
};
