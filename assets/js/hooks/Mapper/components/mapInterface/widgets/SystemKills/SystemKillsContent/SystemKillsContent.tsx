import React, { useMemo } from 'react';
import clsx from 'clsx';
import { DetailedKill } from '@/hooks/Mapper/types/kills';
import { KillRow } from '../components/SystemKillsRow';

interface SystemKillsContentProps {
  kills: DetailedKill[];
  systemNameMap: Record<string, string>;
  compact?: boolean;
  onlyOneSystem?: boolean;
}

export const SystemKillsContent: React.FC<SystemKillsContentProps> = ({
  kills,
  systemNameMap,
  compact = false,
  onlyOneSystem = false,
}) => {
  const sortedKills = useMemo(() => {
    return [...kills].sort((a, b) => {
      const timeA = a.kill_time ? new Date(a.kill_time).getTime() : 0;
      const timeB = b.kill_time ? new Date(b.kill_time).getTime() : 0;
      return timeB - timeA;
    });
  }, [kills]);

  return (
    <div
      className={clsx(
        'flex flex-col w-full text-stone-200 text-xs transition-all duration-300',
        compact ? 'gap-0.5 p-1' : 'gap-1 p-1',
      )}
    >
      {sortedKills.map(kill => {
        const systemIdStr = String(kill.solar_system_id);
        const systemName = systemNameMap[systemIdStr] || `System ${systemIdStr}`;

        return (
          <KillRow
            key={kill.killmail_id}
            killDetails={kill}
            systemName={systemName}
            isCompact={compact}
            onlyOneSystem={onlyOneSystem}
          />
        );
      })}
    </div>
  );
};
