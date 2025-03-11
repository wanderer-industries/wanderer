import React, { useMemo } from 'react';
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

export const SystemKillsContent: React.FC<SystemKillsContentProps> = ({
  kills,
  systemNameMap,
  onlyOneSystem = false,
  timeRange = 4,
  limit,
}) => {
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

  const itemTemplate = useSystemKillsItemTemplate(systemNameMap, onlyOneSystem);

  // Define style for the VirtualScroller
  const virtualScrollerStyle: React.CSSProperties = {
    boxSizing: 'border-box',
    height: '100%', // Use 100% height to fill the container
  };

  return (
    <div className="h-full w-full flex flex-col overflow-hidden" data-testid="system-kills-content">
      <VirtualScroller
        items={processedKills}
        itemSize={ITEM_HEIGHT}
        itemTemplate={itemTemplate}
        className={`w-full h-full flex-1 select-none ${classes.VirtualScroller}`}
        style={virtualScrollerStyle}
        pt={{
          content: {
            className: `custom-scrollbar ${classes.scrollerContent}`,
          },
        }}
      />
    </div>
  );
};

export default SystemKillsContent;
