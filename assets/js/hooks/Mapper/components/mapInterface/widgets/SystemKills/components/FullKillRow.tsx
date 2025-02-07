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
import { VictimRowSubInfo } from './VictimRowSubInfo';
import { WdTooltipWrapper } from '../../../../ui-kit/WdTooltipWrapper';
import classes from './SystemKillRow.module.scss';
import { TooltipPosition } from '@/hooks/Mapper/components/ui-kit';

export interface FullKillRowProps {
  killDetails: DetailedKill;
  systemName: string;
  onlyOneSystem: boolean;
}

export const FullKillRow: React.FC<FullKillRowProps> = ({
  killDetails,
  systemName,
  onlyOneSystem,
}) => {
  const {
    killmail_id = 0,

    // Victim
    victim_char_name = '',
    victim_alliance_ticker = '',
    victim_corp_ticker = '',
    victim_ship_name = '',
    victim_char_id = 0,
    victim_corp_id = 0,
    victim_alliance_id = 0,
    victim_ship_type_id = 0,
    victim_corp_name = '',
    victim_alliance_name = '',

    // Attacker
    final_blow_char_id = 0,
    final_blow_char_name = '',
    final_blow_alliance_ticker = '',
    final_blow_corp_ticker = '',
    final_blow_corp_name = '',
    final_blow_alliance_name = '',
    final_blow_corp_id = 0,
    final_blow_alliance_id = 0,
    final_blow_ship_name = '',
    final_blow_ship_type_id = 0,

    total_value = 0,
    kill_time = '',
  } = killDetails || {};

  const attackerIsNpc = final_blow_char_id === 0;
  const victimAffiliation =
    victim_alliance_ticker || victim_corp_ticker || null;
  const attackerAffiliation = attackerIsNpc
    ? ''
    : final_blow_alliance_ticker || final_blow_corp_ticker || '';

  const killValueFormatted =
    total_value != null && total_value > 0 ? `${formatISK(total_value)} ISK` : null;
  const killTimeAgo = kill_time ? formatTimeMixed(kill_time) : '0h ago';

  // Victim images, now also pulling victimShipUrl
  const {
    victimPortraitUrl,
    victimCorpLogoUrl,
    victimAllianceLogoUrl,
    victimShipUrl,
  } = buildVictimImageUrls({
    victim_char_id,
    victim_ship_type_id,
    victim_corp_id,
    victim_alliance_id,
  });
  // Attacker images
  const {
    attackerPortraitUrl,
    attackerCorpLogoUrl,
    attackerAllianceLogoUrl,
  } = buildAttackerImageUrls({
    final_blow_char_id,
    final_blow_corp_id,
    final_blow_alliance_id,
  });

  // Primary corp/alliance logo for victim
  const { url: victimPrimaryImageUrl, tooltip: victimPrimaryTooltip } =
    getPrimaryLogoAndTooltip(
      victimAllianceLogoUrl,
      victimCorpLogoUrl,
      victim_alliance_name,
      victim_corp_name,
      'Victim'
    );

  // Primary image for attacker => NPC => ship, else corp/alliance
  const { url: attackerPrimaryImageUrl, tooltip: attackerPrimaryTooltip } =
    getAttackerPrimaryImageAndTooltip(
      attackerIsNpc,
      attackerAllianceLogoUrl,
      attackerCorpLogoUrl,
      final_blow_alliance_name,
      final_blow_corp_name,
      final_blow_ship_type_id
    );

  const attackerSubscript = getAttackerSubscript(killDetails);

  return (
    <div
      className={clsx(
        classes.killRowContainer,
        'h-18 w-full justify-between items-start text-sm py-[4px]'
      )}
    >
      <div className="flex items-start gap-1 min-w-0 h-full">
        {victimShipUrl && (
          <div className="relative shrink-0 w-14 h-14 overflow-hidden">
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

        {victimPrimaryImageUrl && (
          <WdTooltipWrapper
            content={victimPrimaryTooltip}
            position={TooltipPosition.top}
          >
            <div className="relative shrink-0 w-14 h-14 overflow-hidden">
              <a
                href={zkillLink('kill', killmail_id)}
                target="_blank"
                rel="noopener noreferrer"
                className="block w-full h-full"
              >
                <img
                  src={victimPrimaryImageUrl}
                  alt="VictimPrimaryLogo"
                  className={clsx(classes.killRowImage, 'w-full h-full object-contain')}
                />
              </a>
            </div>
          </WdTooltipWrapper>
        )}

        <VictimRowSubInfo
          victimCharName={victim_char_name}
          victimCharacterId={victim_char_id}
          victimPortraitUrl={victimPortraitUrl}
        />

        <div className="flex flex-col text-stone-200 leading-4 min-w-0 overflow-hidden">
          <div className="truncate">
            <span className="font-semibold">{victim_char_name}</span>
            {victimAffiliation && (
              <span className="ml-1 text-stone-400">/ {victimAffiliation}</span>
            )}
          </div>
          <div className="truncate text-stone-300">
            {victim_ship_name}
            {killValueFormatted && (
              <>
                <span className="ml-1 text-stone-400">/</span>
                <span className="ml-1 text-green-400">
                  {killValueFormatted}
                </span>
              </>
            )}
          </div>
          <div className="truncate text-stone-400">
            {!onlyOneSystem && systemName && <span>{systemName}</span>}
          </div>
        </div>
      </div>

      <div className="flex items-start gap-1 min-w-0 h-full">
        <div className="flex flex-col items-end leading-4 min-w-0 overflow-hidden text-right">
          {!attackerIsNpc && (
            <div className="truncate font-semibold">
              {final_blow_char_name}
              {attackerAffiliation && (
                <span className="ml-1 text-stone-400">/ {attackerAffiliation}</span>
              )}
            </div>
          )}
          {!attackerIsNpc && final_blow_ship_name && (
            <div className="truncate text-stone-300">{final_blow_ship_name}</div>
          )}
          <div className="truncate text-red-400">{killTimeAgo}</div>
        </div>

        {!attackerIsNpc && attackerPortraitUrl && final_blow_char_id && final_blow_char_id > 0 && (
          <div className="relative shrink-0 w-14 h-14 overflow-hidden">
            <a
              href={zkillLink('character', final_blow_char_id)}
              target="_blank"
              rel="noopener noreferrer"
              className="block w-full h-full"
            >
              <img
                src={attackerPortraitUrl}
                alt="AttackerPortrait"
                className={clsx(classes.killRowImage, 'w-full h-full object-contain')}
              />
            </a>
          </div>
        )}

        {attackerPrimaryImageUrl && (
          <WdTooltipWrapper
            content={attackerPrimaryTooltip}
            position={TooltipPosition.top}
          >
            <div className="relative shrink-0 w-14 h-14 overflow-hidden">
              <a
                href={zkillLink('kill', killmail_id)}
                target="_blank"
                rel="noopener noreferrer"
                className="block w-full h-full"
              >
                <img
                  src={attackerPrimaryImageUrl}
                  alt={attackerIsNpc ? 'NpcShip' : 'AttackerPrimaryLogo'}
                  className={clsx(classes.killRowImage, 'w-full h-full object-contain')}
                />
                {attackerSubscript && (
                  <span
                    className={clsx(
                      attackerSubscript.cssClass,
                      classes.attackerCountLabel
                    )}
                  >
                    {attackerSubscript.label}
                  </span>
                )}
              </a>
            </div>
          </WdTooltipWrapper>
        )}
      </div>
    </div>
  );
};
