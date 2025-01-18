import React from 'react';
import clsx from 'clsx';
import classes from './SystemKillsContent.module.scss';
import { DetailedKill } from '@/hooks/Mapper/types/kills';
import { KillRow } from '../components/SystemKillsRow';

interface SystemKillsContentProps {
  kills: DetailedKill[];
  systemNameMap: Record<string, string>;
}

export const SystemKillsContent: React.FC<SystemKillsContentProps> = ({ kills, systemNameMap }) => {
  if (kills.length === 0) {
    return (
      <div className="w-full h-full flex justify-center items-center select-none text-center text-stone-400/80 text-sm">
        No kills found
      </div>
    );
  }

  return (
    <div className={clsx('flex flex-col gap-2 p-2 text-xs text-stone-200 h-full overflow-auto', classes.Table)}>
      {kills.map(kill => {
        const systemIdStr = String(kill.solar_system_id);
        const systemName = systemNameMap[systemIdStr] || `System ${systemIdStr}`;

        return <KillRow key={kill.killmail_id} kill={kill} systemName={systemName} />;
      })}
    </div>
  );
};
