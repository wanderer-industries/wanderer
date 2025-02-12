import React, { useMemo, useRef, useEffect, useState } from 'react';
import clsx from 'clsx';
import { DetailedKill } from '@/hooks/Mapper/types/kills';
import { VirtualScroller } from 'primereact/virtualscroller';
import { useSystemKillsItemTemplate } from '../hooks/useSystemKillsItemTemplate';
import classes from './SystemKillsContent.module.scss';

export interface SystemKillsContentProps {
  kills: DetailedKill[];
  systemNameMap: Record<string, string>;
  compact?: boolean;
  onlyOneSystem?: boolean;
  autoSize?: boolean;
  timeRange: number;
  limit?: number;
}

export const SystemKillsContent: React.FC<SystemKillsContentProps> = ({
  kills,
  systemNameMap,
  compact = false,
  onlyOneSystem = false,
  autoSize = false,
  timeRange = 1,
  limit,
}) => {
  const processedKills = useMemo(() => {
    // Filter kills with a valid kill_time and sort descending by kill_time.
    const sortedKills = kills
      .filter(k => k.kill_time)
      .sort((a, b) => new Date(b.kill_time!).getTime() - new Date(a.kill_time!).getTime());

    if (limit !== undefined) {
      // If limit is provided, show only the newest kills up to the limit.
      return sortedKills.slice(0, limit);
    } else {
      // Otherwise, filter by timeRange.
      const now = Date.now();
      const cutoff = now - timeRange * 60 * 60 * 1000;
      return sortedKills.filter(k => new Date(k.kill_time!).getTime() >= cutoff);
    }
  }, [kills, timeRange, limit]);

  const itemSize = compact ? 35 : 50;
  const computedHeight = autoSize ? Math.max(processedKills.length, 1) * itemSize : undefined;

  const containerRef = useRef<HTMLDivElement>(null);
  const scrollerRef = useRef<any>(null);
  const [containerHeight, setContainerHeight] = useState<number>(0);

  useEffect(() => {
    if (!autoSize && containerRef.current) {
      const measure = () => {
        const newHeight = containerRef.current?.clientHeight || 0;
        setContainerHeight(newHeight);
        scrollerRef.current?.refresh?.();
      };

      measure();
      const observer = new ResizeObserver(measure);
      observer.observe(containerRef.current);
      window.addEventListener('resize', measure);

      return () => {
        observer.disconnect();
        window.removeEventListener('resize', measure);
      };
    }
  }, [autoSize]);

  const itemTemplate = useSystemKillsItemTemplate(systemNameMap, compact, onlyOneSystem);
  const scrollerHeight = autoSize ? `${computedHeight}px` : containerHeight ? `${containerHeight}px` : '100%';

  return (
    <div ref={autoSize ? undefined : containerRef} className={clsx('w-full h-full', classes.wrapper)}>
      <VirtualScroller
        ref={autoSize ? undefined : scrollerRef}
        items={processedKills}
        itemSize={itemSize}
        itemTemplate={itemTemplate}
        autoSize={autoSize}
        scrollWidth="100%"
        style={{ height: scrollerHeight }}
        className={clsx('w-full h-full custom-scrollbar select-none overflow-x-hidden overflow-y-auto', {
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
