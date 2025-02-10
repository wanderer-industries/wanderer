import React from 'react';
import clsx from 'clsx';
import { DetailedKill } from '@/hooks/Mapper/types/kills';
import {
  formatISK,
  formatTimeMixed,
  zkillLink,
  getAttackerSubscript,
  buildVictimImageUrls,
  buildAttackerImageUrls,
  getPrimaryLogoAndTooltip,
  getAttackerPrimaryImageAndTooltip,
} from '../helpers';
import { WdTooltipWrapper } from '../../../../ui-kit/WdTooltipWrapper';
import classes from './SystemKillRow.module.scss';
import { TooltipPosition } from '@/hooks/Mapper/components/ui-kit';

export interface CompactKillRowProps {
  killDetails: DetailedKill;
  systemName: string;
  onlyOneSystem: boolean;
}

export const CompactKillRow: React.FC<CompactKillRowProps> = ({ killDetails, systemName, onlyOneSystem }) => {
  const {
    killmail_id = 0,
    // Victim
    victim_char_name = 'Unknown Pilot',
    victim_alliance_ticker = '',
    victim_corp_ticker = '',
    victim_ship_name = 'Unknown Ship',
    victim_corp_name = '',
    victim_alliance_name = '',
    victim_char_id = 0,
    victim_corp_id = 0,
    victim_alliance_id = 0,
    victim_ship_type_id = 0,
    // Attacker
    final_blow_char_id = 0,
    final_blow_char_name = '',
    final_blow_alliance_ticker = '',
    final_blow_alliance_name = '',
    final_blow_alliance_id = 0,
    final_blow_corp_ticker = '',
    final_blow_corp_id = 0,
    final_blow_corp_name = '',
    final_blow_ship_type_id = 0,
    kill_time = '',
    total_value = 0,
  } = killDetails || {};

  const attackerIsNpc = final_blow_char_id === 0;

  const victimAffiliationTicker = victim_alliance_ticker || victim_corp_ticker || 'No Ticker';
  const killValueFormatted = total_value != null && total_value > 0 ? `${formatISK(total_value)} ISK` : null;
  const attackerName = attackerIsNpc ? '' : final_blow_char_name;
  const attackerTicker = attackerIsNpc ? '' : final_blow_alliance_ticker || final_blow_corp_ticker || '';
  const killTimeAgo = kill_time ? formatTimeMixed(kill_time) : '0h ago';
  const attackerSubscript = getAttackerSubscript(killDetails);

  const { victimCorpLogoUrl, victimAllianceLogoUrl, victimShipUrl } = buildVictimImageUrls({
    victim_char_id,
    victim_ship_type_id,
    victim_corp_id,
    victim_alliance_id,
  });

  const { attackerCorpLogoUrl, attackerAllianceLogoUrl } = buildAttackerImageUrls({
    final_blow_char_id,
    final_blow_corp_id,
    final_blow_alliance_id,
  });

  const { url: victimPrimaryLogoUrl, tooltip: victimPrimaryTooltip } = getPrimaryLogoAndTooltip(
    victimAllianceLogoUrl,
    victimCorpLogoUrl,
    victim_alliance_name,
    victim_corp_name,
    'Victim',
  );

  const { url: attackerPrimaryImageUrl, tooltip: attackerPrimaryTooltip } = getAttackerPrimaryImageAndTooltip(
    attackerIsNpc,
    attackerAllianceLogoUrl,
    attackerCorpLogoUrl,
    final_blow_alliance_name,
    final_blow_corp_name,
    final_blow_ship_type_id,
  );

  return (
    <div
      className={clsx(
        'h-10 flex items-center border-b border-stone-800',
        'text-xs whitespace-nowrap overflow-hidden leading-none',
      )}
    >
      <div className="flex items-center gap-1">
        {victimShipUrl && (
          <div className="relative shrink-0 w-8 h-8 overflow-hidden">
            <a
              href={zkillLink('kill', killmail_id)}
              target="_blank"
              rel="noopener noreferrer"
              className="block w-full h-full"
            >
              <img
                src={victimShipUrl}
                alt="VictimShip"
                className={clsx(classes.killRowImage, 'w-full h-full object-contain')}
              />
            </a>
          </div>
        )}
        {victimPrimaryLogoUrl && (
          <WdTooltipWrapper content={victimPrimaryTooltip} position={TooltipPosition.top}>
            <a
              href={zkillLink('kill', killmail_id)}
              target="_blank"
              rel="noopener noreferrer"
              className="relative block shrink-0 w-8 h-8 overflow-hidden"
            >
              <img
                src={victimPrimaryLogoUrl}
                alt="VictimPrimaryLogo"
                className={clsx(classes.killRowImage, 'w-full h-full object-contain')}
              />
            </a>
          </WdTooltipWrapper>
        )}
      </div>
      <div className="flex flex-col ml-2 flex-1 min-w-0 overflow-hidden leading-[1rem]">
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
        <div className="flex flex-col items-end flex-1 min-w-0 overflow-hidden text-right leading-[1rem]">
          {!attackerIsNpc && (attackerName || attackerTicker) && (
            <div className="truncate text-stone-200">
              {attackerName}
              {attackerTicker && <span className="ml-1 text-stone-400">/ {attackerTicker}</span>}
            </div>
          )}
          <div className="truncate text-stone-400">
            {!onlyOneSystem && systemName ? (
              <>
                {systemName} / <span className="ml-1 text-red-400">{killTimeAgo}</span>
              </>
            ) : (
              <span className="text-red-400">{killTimeAgo}</span>
            )}
          </div>
        </div>
        {attackerPrimaryImageUrl && (
          <WdTooltipWrapper content={attackerPrimaryTooltip} position={TooltipPosition.top}>
            <a
              href={zkillLink('kill', killmail_id)}
              target="_blank"
              rel="noopener noreferrer"
              className="relative block shrink-0 w-8 h-8 overflow-hidden"
            >
              <img
                src={attackerPrimaryImageUrl}
                alt={attackerIsNpc ? 'NpcShip' : 'AttackerPrimaryLogo'}
                className={clsx(classes.killRowImage, 'w-full h-full object-contain')}
              />
              {attackerSubscript && (
                <span
                  className={clsx(
                    classes.attackerCountLabel,
                    attackerSubscript.cssClass,
                    'text-[0.6rem] leading-none px-[2px]',
                  )}
                >
                  {attackerSubscript.label}
                </span>
              )}
            </a>
          </WdTooltipWrapper>
        )}
      </div>
    </div>
  );
};
