import React, { useMemo } from 'react';
import clsx from 'clsx';
import { DetailedKill } from '@/hooks/Mapper/types/kills';
import { VirtualScroller } from 'primereact/virtualscroller';
import { useSystemKillsItemTemplate } from '../hooks/useSystemKillsItemTemplate';
import classes from './SystemKillsContent.module.scss';

export const ITEM_HEIGHT = 35;

export interface SystemKillsContentProps {
  kills: DetailedKill[];
  systemNameMap: Record<string, string>;
  onlyOneSystem?: boolean;
  timeRange?: number;
  limit?: number;
}

/**
 * A simple VirtualScroller-based list of kills.
 * Always uses 100% height, so the parent container
 * dictates how tall this scroller is.
 */
export const SystemKillsContent: React.FC<SystemKillsContentProps> = ({
  kills,
  systemNameMap,
  onlyOneSystem = false,
  timeRange = 4,
  limit,
}) => {
  const processedKills = useMemo(() => {
    // Make sure we have kills to process
    if (!kills || kills.length === 0) return [];

    // First sort by time (most recent first)
    const sortedKills = kills
      .filter(k => k.kill_time)
      .sort((a, b) => new Date(b.kill_time!).getTime() - new Date(a.kill_time!).getTime());

    // Apply timeRange filter if specified
    let filteredKills = sortedKills;
    if (timeRange !== undefined) {
      const cutoffTime = new Date();
      cutoffTime.setHours(cutoffTime.getHours() - timeRange);
      const cutoffTimestamp = cutoffTime.getTime();

      filteredKills = filteredKills.filter(kill => {
        const killTime = new Date(kill.kill_time!).getTime();
        return killTime >= cutoffTimestamp;
      });
    }

    if (limit !== undefined) {
      return filteredKills.slice(0, limit);
    } else {
      return filteredKills;
    }
  }, [kills, timeRange, limit]);

  const itemTemplate = useSystemKillsItemTemplate(systemNameMap, onlyOneSystem);

  return (
    <div className={clsx('w-full h-full overflow-hidden', classes.wrapper)}>
      <VirtualScroller
        items={processedKills}
        itemSize={ITEM_HEIGHT}
        itemTemplate={itemTemplate}
        scrollWidth="100%"
        style={{ height: '100%', minHeight: '100px' }}
        className={clsx('w-full custom-scrollbar select-none', classes.VirtualScroller)}
        pt={{
          content: {
            className: classes.scrollerContent,
            style: { minHeight: '100px' },
          },
        }}
      />
    </div>
  );
};

export default SystemKillsContent;
