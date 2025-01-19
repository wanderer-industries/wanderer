import React from 'react';
import clsx from 'clsx';
import { DetailedKill } from '@/hooks/Mapper/types/kills';
import { eveImageUrl, zkillLink } from '../helpers';
import classes from './SystemKillsRow.module.scss';

function formatTimeMixed(killTime: string): string {
  const killDate = new Date(killTime);
  const diffMs = Date.now() - killDate.getTime();
  const diffHours = diffMs / (1000 * 60 * 60);

  if (diffHours < 1) {
    const mins = Math.round(diffHours * 60);
    return `${mins}m ago`;
  } else if (diffHours < 24) {
    const hours = Math.round(diffHours);
    return `${hours}h ago`;
  } else {
    const days = diffHours / 24;
    const roundedDays = days.toFixed(1);
    return `${roundedDays}d ago`;
  }
}

function formatISK(value: number): string {
  if (value >= 1_000_000_000_000) {
    return `${(value / 1_000_000_000_000).toFixed(2)}T`;
  } else if (value >= 1_000_000_000) {
    return `${(value / 1_000_000_000).toFixed(2)}B`;
  } else if (value >= 1_000_000) {
    return `${(value / 1_000_000).toFixed(2)}M`;
  } else if (value >= 1_000) {
    return `${(value / 1_000).toFixed(2)}k`;
  }
  return `${Math.round(value)}`;
}

function getAttackerSubscript(kill: DetailedKill) {
  if (kill.npc) {
    return { label: 'npc', cssClass: 'text-purple-400' };
  }
  const count = kill.attacker_count ?? 0;
  if (count === 1) {
    return { label: 'solo', cssClass: 'text-green-400' };
  } else if (count > 1) {
    return { label: String(count), cssClass: 'text-white' };
  }
  return null;
}

interface KillRowProps {
  kill: DetailedKill;
  systemName: string;
  compact?: boolean;
  onlyOneSystem?: boolean;
}

export const KillRow: React.FC<KillRowProps> = ({ kill, systemName, compact = false, onlyOneSystem = false }) => {
  const killmailId = kill.killmail_id;

  const victimShipName = kill.victim_ship_name || 'Unknown Ship';
  const victimTicker = kill.victim_alliance_ticker ?? kill.victim_corp_ticker ?? 'No Ticker';
  const attackerTicker = kill.final_blow_alliance_ticker ?? kill.final_blow_corp_ticker ?? 'No Ticker';
  const timeAgo = kill.kill_time ? formatTimeMixed(kill.kill_time) : '0h ago';

  const rawValue = kill.total_value ?? 0;
  const totalValue = rawValue > 0 ? `${formatISK(rawValue)} ISK` : null;

  const victimPortraitUrl = eveImageUrl('characters', kill.victim_char_id, 'portrait', 64);
  const victimShipUrl = eveImageUrl('types', kill.victim_ship_type_id, 'render', 64);
  const subscriptData = getAttackerSubscript(kill);

  const portraitSize = compact ? 24 : 40;
  const shipSize = compact ? 32 : 48;

  return (
    <div
      className={clsx(
        'flex border-b border-stone-700 whitespace-nowrap overflow-hidden',
        'transition-all duration-300',
        compact ? 'px-2 py-1 text-xs' : 'p-2 text-sm',
      )}
    >
      <div className="flex items-center min-w-0 overflow-hidden">
        {victimPortraitUrl && (
          <a
            href={zkillLink('character', kill.victim_char_id)}
            target="_blank"
            rel="noopener noreferrer"
            className="shrink-0"
          >
            <img
              src={victimPortraitUrl}
              alt="VictimPortrait"
              width={portraitSize}
              height={portraitSize}
              className="rounded-full"
            />
          </a>
        )}

        <div
          className={clsx(
            'flex flex-col ml-2 min-w-0 overflow-hidden',
            // Tighter spacing if compact
            compact ? 'gap-0.5' : 'gap-1',
          )}
        >
          <div className="flex items-center gap-2 min-w-0 overflow-hidden">
            <span className="truncate text-stone-200">{victimShipName}</span>
            <span className="text-stone-500">|</span>
            <span className="truncate text-stone-400">{victimTicker}</span>
          </div>
          {!compact && <span className="text-stone-400 truncate">{timeAgo}</span>}
        </div>
      </div>
      <div className="flex ml-auto items-center min-w-0 overflow-hidden">
        {compact && (
          <div className={clsx('flex items-center gap-1 text-stone-400 ml-2 mr-2')}>
            <span>{timeAgo}</span>
            <span className="text-stone-600">|</span>
            {!onlyOneSystem && (
              <>
                <span className="text-stone-300">{systemName}</span>
                <span className="text-stone-600">|</span>
              </>
            )}
            <span className="text-stone-300">{attackerTicker}</span>
          </div>
        )}
        {!compact && (
          <div className={clsx('flex flex-col items-end justify-center min-w-0 overflow-hidden', 'mr-3')}>
            {!onlyOneSystem && <span className="text-stone-300 text-sm truncate">{systemName}</span>}
            {totalValue && <span className="text-green-400 text-xs truncate">{totalValue}</span>}
            <span className="text-stone-300 text-sm truncate">{attackerTicker}</span>
          </div>
        )}
        {victimShipUrl && (
          <a
            href={zkillLink('kill', killmailId)}
            target="_blank"
            rel="noopener noreferrer"
            className="relative shrink-0"
          >
            <img src={victimShipUrl} alt="VictimShip" width={shipSize} height={shipSize} className="rounded-full" />
            {subscriptData && (
              <span className={clsx(classes.attackerCountLabel, subscriptData.cssClass)}>{subscriptData.label}</span>
            )}
          </a>
        )}
      </div>
    </div>
  );
};
