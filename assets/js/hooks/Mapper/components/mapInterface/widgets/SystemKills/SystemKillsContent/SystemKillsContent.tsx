import clsx from 'clsx';
import React, { useMemo } from 'react';
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

  if (sortedKills.length === 0) {
    return (
      <div className="w-full h-full flex justify-center items-center text-center text-stone-400/80 text-sm">
        No kills found
      </div>
    );
  }

  return (
    <div
      className={clsx(
        'flex flex-col w-full text-stone-200 text-xs transition-all duration-300',
        compact ? 'gap-1 p-1' : 'gap-2 p-2',
      )}
    >
      {sortedKills.map(kill => {
        const systemIdStr = String(kill.solar_system_id);
        const systemName = systemNameMap[systemIdStr] || `System ${systemIdStr}`;

        return (
          <KillRow
            key={kill.killmail_id}
            kill={kill}
            systemName={systemName}
            compact={compact}
            onlyOneSystem={onlyOneSystem}
          />
        );
      })}
    </div>
  );
};
