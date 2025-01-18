import clsx from 'clsx';
import { PrimeIcons } from 'primereact/api';
import { WdTooltip, TooltipPosition } from '../../../../components/ui-kit';
import { SystemKillsContent } from '../../../mapInterface/widgets/SystemKills/SystemKillsContent/SystemKillsContent';
import { useKillsCounter } from '../../hooks/useKillsCounter';
import { MARKER_BOOKMARK_BG_STYLES } from '@/hooks/Mapper/components/map/constants';
import styles from './SolarSystemKillsCounter.module.scss';

interface KillsBookmarkTooltipProps {
  killsCount: number;
  killsActivityType: string | null;
  systemId: string;
}

export function KillsCounter({ killsCount, killsActivityType, systemId }: KillsBookmarkTooltipProps) {
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
    <>
      <div className={styles.KillsCounterLayer}>
        <div
          style={{
            position: 'absolute',
            top: -21,
            right: 4,
            pointerEvents: 'auto',
          }}
          className="killsTrigger"
        >
          <div className={clsx(styles.KillsBookmark, MARKER_BOOKMARK_BG_STYLES[killsActivityType!])}>
            <div className={styles.KillsBookmarkWithIcon}>
              <span className={clsx(PrimeIcons.BOLT, styles.pi)} />
              <span className={styles.text}>{killsCount}</span>
            </div>
          </div>
        </div>
      </div>
      <WdTooltip
        targetSelector=".killsTrigger"
        position={TooltipPosition.top}
        offset={2}
        interactive={true}
        className={styles.TooltipContainer}
        content={tooltipContent}
      />
    </>
  );
}
