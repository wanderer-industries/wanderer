import { useMemo } from 'react';
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
import { WdTooltipWrapper } from '@/hooks/Mapper/components/ui-kit';
import classes from './KillRowDetail.module.scss';
import { TooltipPosition } from '@/hooks/Mapper/components/ui-kit';
import { WithClassName } from '@/hooks/Mapper/types/common.ts';

export type CompactKillRowProps = {
  killDetails: DetailedKill;
  systemName: string;
  onlyOneSystem: boolean;
} & WithClassName;

export const KillRowDetail = ({ killDetails, systemName, onlyOneSystem, className }: CompactKillRowProps) => {
  const {
    killmail_id = 0,
    // Victim data
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
    // Attacker data
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

  // Define victim affiliation ticker.
  const victimAffiliationTicker = victim_alliance_ticker || victim_corp_ticker || 'No Ticker';

  const killValueFormatted = total_value != null && total_value > 0 ? `${formatISK(total_value)} ISK` : null;
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

  const { url: attackerPrimaryImageUrl, tooltip: attackerPrimaryTooltip } = useMemo(
    () =>
      getAttackerPrimaryImageAndTooltip(
        attackerIsNpc,
        attackerAllianceLogoUrl,
        attackerCorpLogoUrl,
        final_blow_alliance_name,
        final_blow_corp_name,
        final_blow_ship_type_id,
      ),
    [
      attackerAllianceLogoUrl,
      attackerCorpLogoUrl,
      attackerIsNpc,
      final_blow_alliance_name,
      final_blow_corp_name,
      final_blow_ship_type_id,
    ],
  );

  // Define attackerTicker to use the alliance ticker if available, otherwise the corp ticker.
  const attackerTicker = attackerIsNpc ? '' : final_blow_alliance_ticker || final_blow_corp_ticker || '';

  // For the attacker image link: if the attacker is not an NPC, link to the character page; otherwise, link to the kill page.
  const attackerLink = attackerIsNpc ? zkillLink('kill', killmail_id) : zkillLink('character', final_blow_char_id);

  return (
    <div
      className={clsx(
        'h-10 flex items-center border-b border-stone-800',
        'text-xs whitespace-nowrap overflow-hidden leading-none',
        'px-1',
        className,
      )}
    >
      {/* Victim Section */}
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
                alt="Victim Ship"
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
                alt="Victim Primary Logo"
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
        <div className="truncate text-stone-300 flex items-center gap-1">
          <span className="text-stone-400 overflow-hidden text-ellipsis whitespace-nowrap max-w-[140px]">
            {victim_ship_name}
          </span>
          {killValueFormatted && (
            <>
              <span className="text-stone-400">/</span>
              <span className="text-green-400">{killValueFormatted}</span>
            </>
          )}
        </div>
      </div>
      <div className="flex items-center ml-auto gap-2">
        <div className="flex flex-col items-end flex-1 min-w-0 overflow-hidden text-right leading-[1rem]">
          {!attackerIsNpc && (final_blow_char_name || attackerTicker) && (
            <div className="truncate text-stone-200">
              {final_blow_char_name}
              {!attackerIsNpc && attackerTicker && <span className="ml-1 text-stone-400">/ {attackerTicker}</span>}
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
              href={attackerLink}
              target="_blank"
              rel="noopener noreferrer"
              className="relative block shrink-0 w-8 h-8 overflow-hidden"
            >
              <img
                src={attackerPrimaryImageUrl}
                alt={attackerIsNpc ? 'NPC Ship' : 'Attacker Primary Logo'}
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
