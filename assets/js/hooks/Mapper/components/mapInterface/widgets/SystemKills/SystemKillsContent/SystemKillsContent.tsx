import clsx from 'clsx';
import React from 'react';
import { DetailedKill } from '@/hooks/Mapper/types/kills';
import { KillRow } from '../components/SystemKillsRow';

interface SystemKillsContentProps {
  kills: DetailedKill[];
  systemNameMap: Record<string, string>;
  compact?: boolean;
}

export const SystemKillsContent: React.FC<SystemKillsContentProps> = ({ kills, systemNameMap, compact = false }) => {
  if (kills.length === 0) {
    return (
      <div className="w-full h-full flex justify-center items-center text-center text-stone-400/80 text-sm">
        No kills found
      </div>
    );
  }

  return (
    <div className={clsx('flex flex-col w-full text-stone-200 text-xs', compact ? 'gap-1 p-1' : 'gap-2 p-2')}>
      {kills.map(kill => {
        const systemIdStr = String(kill.solar_system_id);
        const systemName = systemNameMap[systemIdStr] || `System ${systemIdStr}`;
        return <KillRow key={kill.killmail_id} kill={kill} systemName={systemName} compact={compact} />;
      })}
    </div>
  );
};
