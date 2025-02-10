import React, { useMemo, useRef, useEffect, useState } from 'react';
import clsx from 'clsx';
import { DetailedKill } from '@/hooks/Mapper/types/kills';
import { VirtualScroller } from 'primereact/virtualscroller';
import { useSystemKillsItemTemplate } from '../hooks/useSystemKillsTemplate';

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
    const validKills = kills.filter(kill => kill.kill_time);

    const sortedKills = validKills.sort((a, b) => {
      const timeA = a.kill_time ? new Date(a.kill_time).getTime() : 0;
      const timeB = b.kill_time ? new Date(b.kill_time).getTime() : 0;
      return timeB - timeA;
    });

    if (limit != null) {
      return sortedKills.slice(0, limit);
    } else {
      const now = Date.now();
      const cutoff = now - timeRange * 60 * 60 * 1000;
      return sortedKills.filter(kill => {
        if (!kill.kill_time) return false;
        const killTime = new Date(kill.kill_time).getTime();
        return killTime >= cutoff;
      });
    }
  }, [kills, timeRange, limit]);

  const itemSize = compact ? 35 : 50;
  const computedHeight = autoSize ? Math.max(processedKills.length, 1) * itemSize + 5 : undefined;

  const containerRef = useRef<HTMLDivElement>(null);
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  const scrollerRef = useRef<any>(null);
  const [containerHeight, setContainerHeight] = useState<number>(0);

  useEffect(() => {
    if (!autoSize && containerRef.current) {
      const measure = () => {
        const newHeight = containerRef.current?.clientHeight ?? 0;
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

  if (!autoSize) {
    return (
      <div ref={containerRef} className="w-full h-full">
        <VirtualScroller
          ref={scrollerRef}
          items={processedKills}
          itemSize={itemSize}
          itemTemplate={itemTemplate}
          autoSize={false}
          style={{
            height: containerHeight ? `${containerHeight}px` : '100%',
          }}
          className={clsx('w-full h-full overflow-x-hidden overflow-y-auto custom-scrollbar select-none')}
        />
      </div>
    );
  }

  return (
    <VirtualScroller
      items={processedKills}
      itemSize={itemSize}
      itemTemplate={itemTemplate}
      autoSize
      style={{ height: `${computedHeight}px` }}
      className={clsx('w-full h-full overflow-x-hidden overflow-y-auto custom-scrollbar select-none')}
    />
  );
};
