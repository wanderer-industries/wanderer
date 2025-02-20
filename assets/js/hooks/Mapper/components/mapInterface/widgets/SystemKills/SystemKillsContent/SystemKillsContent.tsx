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
  autoSize?: boolean;
  timeRange?: number;
  limit?: number;
}

export const SystemKillsContent: React.FC<SystemKillsContentProps> = ({
  kills,
  systemNameMap,
  onlyOneSystem = false,
  autoSize = false,
  timeRange = 4,
  limit,
}) => {
  const processedKills = useMemo(() => {
    const sortedKills = kills
      .filter(k => k.kill_time)
      .sort((a, b) => new Date(b.kill_time!).getTime() - new Date(a.kill_time!).getTime());

    if (limit !== undefined) {
      return sortedKills.slice(0, limit);
    } else {
      const now = Date.now();
      const cutoff = now - timeRange * 60 * 60 * 1000;
      return sortedKills.filter(k => new Date(k.kill_time!).getTime() >= cutoff);
    }
  }, [kills, timeRange, limit]);

  const computedHeight = autoSize ? Math.max(processedKills.length, 1) * ITEM_HEIGHT : undefined;
  const scrollerHeight = autoSize ? `${computedHeight}px` : '100%';

  const itemTemplate = useSystemKillsItemTemplate(systemNameMap, onlyOneSystem);

  return (
    <div className={clsx('w-full h-full', classes.wrapper)}>
      <VirtualScroller
        items={processedKills}
        itemSize={ITEM_HEIGHT}
        itemTemplate={itemTemplate}
        autoSize={autoSize}
        scrollWidth="100%"
        style={{ height: scrollerHeight }}
        className={clsx('w-full h-full custom-scrollbar select-none', {
          [classes.VirtualScroller]: !autoSize,
        })}
        pt={{
          content: {
            className: classes.scrollerContent,
          },
        }}
      />
    </div>
  );
};

export default SystemKillsContent;
