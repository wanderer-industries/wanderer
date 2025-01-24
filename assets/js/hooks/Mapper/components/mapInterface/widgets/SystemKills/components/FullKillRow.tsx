import React from 'react';
import clsx from 'clsx';
import { DetailedKill } from '@/hooks/Mapper/types/kills';
import { KillRowSubInfo } from './KillRowSubInfo';
import {
  formatISK,
  formatTimeMixed,
  zkillLink,
  getAttackerSubscript,
  buildVictimImageUrls,
  buildAttackerShipUrl,
} from '../helpers';
import classes from './SystemKillRow.module.scss';

export interface FullKillRowProps {
  killDetails: DetailedKill;
  systemName: string;
  onlyOneSystem: boolean;
}

export const FullKillRow: React.FC<FullKillRowProps> = ({ killDetails, systemName, onlyOneSystem }) => {
  const {
    killmail_id,
    victim_char_name = '',
    victim_alliance_ticker,
    victim_corp_ticker,
    victim_ship_name = '',
    victim_char_id,
    victim_corp_id,
    victim_alliance_id,
    victim_ship_type_id,

    total_value,
    kill_time,

    final_blow_char_id,
    final_blow_char_name = '',
    final_blow_alliance_ticker,
    final_blow_corp_ticker,
    final_blow_ship_name = '',
    final_blow_ship_type_id,
  } = killDetails;

  const attackerIsNpc = final_blow_char_id == null;

  const victimAffiliation = victim_alliance_ticker || victim_corp_ticker || '';
  const attackerAffiliation = attackerIsNpc ? '' : final_blow_alliance_ticker || final_blow_corp_ticker || '';

  const killValueFormatted = total_value && total_value > 0 ? `${formatISK(total_value)} ISK` : null;
  const killTimeAgo = kill_time ? formatTimeMixed(kill_time) : '0h ago';

  const { victimPortraitUrl, victimCorpLogoUrl, victimAllianceLogoUrl, victimShipUrl } = buildVictimImageUrls({
    victim_char_id,
    victim_ship_type_id,
    victim_corp_id,
    victim_alliance_id,
  });

  const finalBlowShipUrl = buildAttackerShipUrl(final_blow_ship_type_id);

  const attackerSubscript = getAttackerSubscript(killDetails);

  return (
    <div
      className={clsx(
        classes.killRowContainer,
        'h-16 w-full justify-between items-start bg-stone-900 hover:bg-stone-800 text-sm',
        'border border-stone-800 rounded-[4px]',
      )}
    >
      <div className="flex items-start gap-2 pl-1 min-w-0 pt-1 h-full">
        {victimShipUrl && (
          <div className="relative shrink-0 w-14 h-14 overflow-hidden">
            <a
              href={zkillLink('kill', killmail_id)}
              target="_blank"
              rel="noopener noreferrer"
              className="block w-full h-full"
            >
              <img src={victimShipUrl} alt="VictimShip" className={clsx(classes.killRowImage, 'w-full h-full')} />
            </a>
          </div>
        )}

        <div className="flex items-start h-14 gap-1 shrink-0">
          <KillRowSubInfo
            victimCorpId={victim_corp_id}
            victimCorpLogoUrl={victimCorpLogoUrl}
            victimAllianceId={victim_alliance_id}
            victimAllianceLogoUrl={victimAllianceLogoUrl}
            victimCharacterId={victim_char_id}
            victimPortraitUrl={victimPortraitUrl}
          />
        </div>

        <div className="flex flex-col text-stone-200 leading-4 min-w-0 overflow-hidden">
          <div className="truncate">
            <span className="font-semibold">{victim_char_name}</span>
            {victimAffiliation && <span className="ml-1 text-stone-400">/ {victimAffiliation}</span>}
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
          <div className="truncate text-stone-400">{!onlyOneSystem && systemName && <span>{systemName}</span>}</div>
        </div>
      </div>

      <div className="flex items-start gap-2 pr-1 pt-1 min-w-0 h-full">
        <div className="flex flex-col items-end leading-4 min-w-0 overflow-hidden text-right">
          {!attackerIsNpc && (
            <div className="truncate font-semibold">
              {final_blow_char_name}
              {attackerAffiliation && <span className="ml-1 text-stone-400">/ {attackerAffiliation}</span>}
            </div>
          )}
          {!attackerIsNpc && final_blow_ship_name && (
            <div className="truncate text-stone-300">{final_blow_ship_name}</div>
          )}
          <div className="truncate text-red-400">{killTimeAgo}</div>
        </div>
        {finalBlowShipUrl && (
          <div className="relative shrink-0 w-14 h-14 overflow-hidden">
            <a
              href={zkillLink('kill', killmail_id)}
              target="_blank"
              rel="noopener noreferrer"
              className="block w-full h-full"
            >
              <img src={finalBlowShipUrl} alt="AttackerShip" className={clsx(classes.killRowImage, 'w-full h-full')} />
              {attackerSubscript && (
                <span className={clsx(attackerSubscript.cssClass, classes.attackerCountLabel)}>
                  {attackerSubscript.label}
                </span>
              )}
            </a>
          </div>
        )}
      </div>
    </div>
  );
};
