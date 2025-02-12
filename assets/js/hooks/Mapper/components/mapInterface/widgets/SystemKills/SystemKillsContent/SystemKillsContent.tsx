import React, { useMemo, useRef, useEffect, useState } from 'react';
import clsx from 'clsx';
import { DetailedKill } from '@/hooks/Mapper/types/kills';
import { VirtualScroller } from 'primereact/virtualscroller';
import { useSystemKillsItemTemplate } from '../hooks/useSystemKillsItemTemplate';
import classes from './SystemKillsContent.module.scss';

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

  const itemSize = 35;
  const computedHeight = autoSize ? Math.max(processedKills.length, 1) * itemSize : undefined;

  const containerRef = useRef<HTMLDivElement>(null);
  const scrollerRef = useRef<VirtualScroller | null>(null);
  const [containerHeight, setContainerHeight] = useState<number>(0);

  useEffect(() => {
    if (!autoSize && containerRef.current) {
      const measure = () => {
        const newHeight = containerRef.current?.clientHeight || 0;
        setContainerHeight(newHeight);
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

  const itemTemplate = useSystemKillsItemTemplate(systemNameMap, onlyOneSystem);
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
