import React from 'react';
import clsx from 'clsx';
import { DetailedKill } from '@/hooks/Mapper/types/kills';
import {
  formatISK,
  formatTimeMixed,
  zkillLink,
  getAttackerSubscript,
  buildVictimImageUrls,
  buildAttackerShipUrl,
} from '../helpers';
import classes from './SystemKillRow.module.scss';

export interface CompactKillRowProps {
  killDetails: DetailedKill;
  systemName: string;
  onlyOneSystem: boolean;
}

export const CompactKillRow: React.FC<CompactKillRowProps> = ({ killDetails, systemName, onlyOneSystem }) => {
  const {
    killmail_id,
    victim_char_name = 'Unknown Pilot',
    victim_ship_name = 'Unknown Ship',
    victim_alliance_ticker,
    victim_corp_ticker,
    victim_char_id,
    victim_corp_id,
    victim_alliance_id,
    victim_ship_type_id,

    final_blow_char_id,
    final_blow_char_name = '',
    final_blow_alliance_ticker,
    final_blow_corp_ticker,
    final_blow_ship_type_id,

    kill_time,
    total_value,
  } = killDetails;

  const attackerIsNpc = final_blow_char_id == null;

  const victimAffiliationTicker = victim_alliance_ticker || victim_corp_ticker || 'No Ticker';
  const killValueFormatted = total_value && total_value > 0 ? `${formatISK(total_value)} ISK` : null;

  const attackerName = attackerIsNpc ? '' : final_blow_char_name;
  const attackerTicker = attackerIsNpc ? '' : final_blow_alliance_ticker || final_blow_corp_ticker || '';

  const killTimeAgo = kill_time ? formatTimeMixed(kill_time) : '0h ago';
  const attackerSubscript = getAttackerSubscript(killDetails);

  const { victimShipUrl } = buildVictimImageUrls({
    victim_char_id,
    victim_ship_type_id,
    victim_corp_id,
    victim_alliance_id,
  });
  const finalBlowShipUrl = buildAttackerShipUrl(final_blow_ship_type_id);

  return (
    <div
      className={clsx(
        'h-10 flex items-center border-b border-stone-800',
        'text-xs whitespace-nowrap overflow-hidden leading-none',
      )}
    >
      {victimShipUrl && (
        <a
          href={zkillLink('kill', killmail_id)}
          target="_blank"
          rel="noopener noreferrer"
          className="relative shrink-0 w-8 h-8 overflow-hidden"
        >
          <img src={victimShipUrl} alt="VictimShip" className={clsx(classes.killRowImage, 'w-full h-full')} />
        </a>
      )}

      <div className="flex flex-col ml-2 min-w-0 overflow-hidden leading-[1rem]">
        <div className="truncate text-stone-200">
          {victim_char_name}
          <span className="text-stone-400"> / {victimAffiliationTicker}</span>
        </div>
        <div className="truncate text-stone-300">
          {victim_ship_name}
          {killValueFormatted && (
            <>
              <span className="ml-1 text-stone-400">/</span>
              <span className="ml-1 text-green-400">{killValueFormatted}</span>
            </>
          )}
        </div>
      </div>

      <div className="flex items-center ml-auto gap-2">
        <div className="flex flex-col items-end min-w-0 overflow-hidden text-right leading-[1rem]">
          {!attackerIsNpc && (attackerName || attackerTicker) && (
            <div className="truncate text-stone-200">
              {attackerName}
              {attackerTicker && <span className="ml-1 text-stone-400">/ {attackerTicker}</span>}
            </div>
          )}
          <div className="truncate text-stone-400">
            {!onlyOneSystem && systemName ? (
              <>
                {systemName} /<span className="ml-1 text-red-400">{killTimeAgo}</span>
              </>
            ) : (
              <span className="text-red-400">{killTimeAgo}</span>
            )}
          </div>
        </div>

        {finalBlowShipUrl && (
          <a
            href={zkillLink('kill', killmail_id)}
            target="_blank"
            rel="noopener noreferrer"
            className="relative shrink-0 w-8 h-8 overflow-hidden"
          >
            <img src={finalBlowShipUrl} alt="AttackerShip" className={clsx(classes.killRowImage, 'w-full h-full')} />
            {attackerSubscript && (
              <span
                className={clsx(
                  classes.attackerCountLabel,
                  attackerSubscript.cssClass,
                  'text-[0.6rem] leading-none px-[2px]',
                )}
                style={{ bottom: 0, right: 0 }}
              >
                {attackerSubscript.label}
              </span>
            )}
          </a>
        )}
      </div>
    </div>
  );
};
