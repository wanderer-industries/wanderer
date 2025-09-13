import { useMemo } from 'react';
import { DetailedKill } from '@/hooks/Mapper/types/kills';
import { VirtualScroller } from 'primereact/virtualscroller';
import { useSystemKillsItemTemplate } from '../hooks/useSystemKillsItemTemplate';
import clsx from 'clsx';
import { WithClassName } from '@/hooks/Mapper/types/common.ts';

export const KILLS_ROW_HEIGHT = 40;

export type SystemKillsContentProps = {
  kills: DetailedKill[];
  onlyOneSystem?: boolean;
  timeRange?: number;
  limit?: number;
} & WithClassName;

export const SystemKillsList = ({
  kills,
  onlyOneSystem = false,
  timeRange = 4,
  limit,
  className,
}: SystemKillsContentProps) => {
  const processedKills = useMemo(() => {
    if (!kills || kills.length === 0) return [];

    // sort by newest first
    const sortedKills = kills
      .filter(k => k.kill_time)
      .sort((a, b) => new Date(b.kill_time!).getTime() - new Date(a.kill_time!).getTime());

    // filter by timeRange
    let filteredKills = sortedKills;
    if (timeRange !== undefined) {
      const cutoffTime = new Date();
      cutoffTime.setHours(cutoffTime.getHours() - timeRange);
      filteredKills = sortedKills.filter(kill => {
        const killTime = new Date(kill.kill_time!).getTime();
        return killTime >= cutoffTime.getTime();
      });
    }

    // apply limit if present
    if (limit !== undefined) {
      return filteredKills.slice(0, limit);
    }
    return filteredKills;
  }, [kills, timeRange, limit]);

  const itemTemplate = useSystemKillsItemTemplate(onlyOneSystem);

  return (
    <VirtualScroller
      items={processedKills}
      itemSize={KILLS_ROW_HEIGHT}
      itemTemplate={itemTemplate}
      className={clsx(
        'w-full flex-1 select-none !h-full overflow-x-hidden overflow-y-auto custom-scrollbar',
        className,
      )}
    />
  );
};
