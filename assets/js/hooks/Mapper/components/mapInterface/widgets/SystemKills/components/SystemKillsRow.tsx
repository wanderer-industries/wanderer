import React from 'react';
import { DetailedKill } from '@/hooks/Mapper/types/kills';
import { eveImageUrl, zkillLink, formatKillTime } from '../helpers';
import classes from './SystemKillsRow.module.scss';
import clsx from 'clsx';

interface KillRowProps {
  kill: DetailedKill;
  systemName: string;
  compact?: boolean;
}

export const KillRow: React.FC<KillRowProps> = ({ kill, systemName, compact }) => {
  const killmailId = kill.killmail_id;
  const killTimeString = kill.kill_time;
  const victimShipUrl = eveImageUrl('types', kill.victim_ship_type_id, 'render', 64);
  const victimCharUrl = eveImageUrl('characters', kill.victim_char_id, 'portrait', 64);
  const victimCorpUrl = eveImageUrl('corporations', kill.victim_corp_id, 'logo', 64);
  const victimAllianceUrl = eveImageUrl('alliances', kill.victim_alliance_id, 'logo', 64);
  const attackerShipUrl = eveImageUrl('types', kill.final_blow_ship_type_id, 'render', 64);
  const attackerCharUrl = eveImageUrl('characters', kill.final_blow_char_id, 'portrait', 64);
  const attackerCorpUrl = eveImageUrl('corporations', kill.final_blow_corp_id, 'logo', 64);
  const attackerAllianceUrl = eveImageUrl('alliances', kill.final_blow_alliance_id, 'logo', 64);
  const isNpc = !!kill.npc;
  let attackerCountLabel = '';
  if (isNpc) {
    attackerCountLabel = 'npc';
  } else if (kill.attacker_count) {
    attackerCountLabel = kill.attacker_count === 1 ? 'solo' : String(kill.attacker_count);
  }
  let labelTextColor = 'text-white';
  if (attackerCountLabel === 'solo') {
    labelTextColor = 'text-green-400';
  } else if (attackerCountLabel === 'npc') {
    labelTextColor = 'text-purple-400';
  }
  const formattedTime = killTimeString ? formatKillTime(killTimeString) : null;
  const attackerOrgUrl = attackerAllianceUrl || attackerCorpUrl;

  if (compact) {
    return (
      <div
        className={clsx(
          'flex items-center border-b border-stone-700 text-xs whitespace-nowrap overflow-hidden',
          'px-2',
          'h-10',
        )}
      >
        <div className="flex items-center gap-2 min-w-0 overflow-hidden mr-10">
          {victimShipUrl && (
            <a href={zkillLink('kill', killmailId)} target="_blank" rel="noopener noreferrer">
              <img src={victimShipUrl} alt="VictimShip" width={28} height={28} style={{ borderRadius: '50%' }} />
            </a>
          )}
          {victimCharUrl && (
            <a href={zkillLink('character', kill.victim_char_id)} target="_blank" rel="noopener noreferrer">
              <img src={victimCharUrl} alt="VictimCharacter" width={20} height={20} style={{ borderRadius: '50%' }} />
            </a>
          )}
        </div>
        <div className="flex items-center gap-2 mr-4">
          {attackerShipUrl && (
            <a href={zkillLink('kill', killmailId)} target="_blank" rel="noopener noreferrer">
              <img src={attackerShipUrl} alt="AttackerShip" width={28} height={28} style={{ borderRadius: '50%' }} />
            </a>
          )}
          {attackerCharUrl && !isNpc && (
            <a href={zkillLink('character', kill.final_blow_char_id)} target="_blank" rel="noopener noreferrer">
              <img
                src={attackerCharUrl}
                alt="AttackerCharacter"
                width={20}
                height={20}
                style={{ borderRadius: '50%' }}
              />
            </a>
          )}
          <div className="relative min-w-0">
            {attackerOrgUrl && !isNpc && (
              <a
                href={
                  attackerAllianceUrl
                    ? zkillLink('alliance', kill.final_blow_alliance_id)
                    : zkillLink('corporation', kill.final_blow_corp_id)
                }
                target="_blank"
                rel="noopener noreferrer"
              >
                <img src={attackerOrgUrl} alt="AttackerOrg" width={24} height={24} style={{ borderRadius: '50%' }} />
              </a>
            )}
            {attackerCountLabel && (
              <span className={`${classes.attackerCountLabelCompact} ${labelTextColor}`}>{attackerCountLabel}</span>
            )}
          </div>
        </div>
        <div className="ml-auto text-right text-[10px] text-stone-300 flex flex-col">
          {formattedTime && <span>{formattedTime}</span>}
          <span>{systemName}</span>
        </div>
      </div>
    );
  } else {
    return (
      <div className="table w-full table-fixed border-b border-stone-700">
        <div className="table-row">
          <div className="table-cell align-middle p-1 text-left" style={{ width: '33%' }}>
            <div className="flex items-center space-x-2">
              {victimShipUrl && (
                <a href={zkillLink('kill', killmailId)} target="_blank" rel="noopener noreferrer">
                  <img src={victimShipUrl} alt="VictimShip" style={{ width: 40, height: 40, borderRadius: '50%' }} />
                </a>
              )}
              {victimCharUrl && (
                <a href={zkillLink('character', kill.victim_char_id)} target="_blank" rel="noopener noreferrer">
                  <img
                    src={victimCharUrl}
                    alt="VictimCharacter"
                    style={{ width: 28, height: 28, borderRadius: '50%' }}
                  />
                </a>
              )}
              <div className="flex flex-col items-center">
                {victimCorpUrl && (
                  <a href={zkillLink('corporation', kill.victim_corp_id)} target="_blank" rel="noopener noreferrer">
                    <img src={victimCorpUrl} alt="VictimCorp" style={{ width: 28, height: 28, borderRadius: '50%' }} />
                  </a>
                )}
                {victimAllianceUrl && (
                  <a href={zkillLink('alliance', kill.victim_alliance_id)} target="_blank" rel="noopener noreferrer">
                    <img
                      src={victimAllianceUrl}
                      alt="VictimAlliance"
                      style={{ width: 28, height: 28, borderRadius: '50%', marginTop: '4px' }}
                    />
                  </a>
                )}
              </div>
            </div>
          </div>
          <div className="table-cell align-middle p-1 text-right pl-8" style={{ width: '33%' }}>
            <div className="flex justify-end space-x-2">
              <div className="relative w-14 h-14 flex items-center justify-center">
                {attackerShipUrl && (
                  <a href={zkillLink('kill', killmailId)} target="_blank" rel="noopener noreferrer">
                    <img
                      src={attackerShipUrl}
                      alt="AttackerShip"
                      style={{ width: 40, height: 40, borderRadius: '50%' }}
                    />
                  </a>
                )}
                {attackerCountLabel && (
                  <span className={`${classes.attackerCountLabel} ${labelTextColor}`}>{attackerCountLabel}</span>
                )}
              </div>
              <div className="w-10 flex flex-col items-center justify-center">
                {!isNpc && attackerCharUrl && (
                  <a href={zkillLink('character', kill.final_blow_char_id)} target="_blank" rel="noopener noreferrer">
                    <img
                      src={attackerCharUrl}
                      alt="AttackerCharacter"
                      style={{ width: 28, height: 28, borderRadius: '50%' }}
                    />
                  </a>
                )}
              </div>
              <div className="w-10 flex flex-col items-center">
                {!isNpc && attackerCorpUrl && (
                  <a href={zkillLink('corporation', kill.final_blow_corp_id)} target="_blank" rel="noopener noreferrer">
                    <img
                      src={attackerCorpUrl}
                      alt="AttackerCorp"
                      style={{ width: 28, height: 28, borderRadius: '50%' }}
                    />
                  </a>
                )}
                {!isNpc && attackerAllianceUrl && (
                  <a
                    href={zkillLink('alliance', kill.final_blow_alliance_id)}
                    target="_blank"
                    rel="noopener noreferrer"
                  >
                    <img
                      src={attackerAllianceUrl}
                      alt="AttackerAlliance"
                      style={{ width: 28, height: 28, borderRadius: '50%', marginTop: '4px' }}
                    />
                  </a>
                )}
              </div>
            </div>
          </div>
          <div className="table-cell align-middle p-1 text-right text-[10px] text-stone-300" style={{ width: '33%' }}>
            <div className="flex flex-col items-end">
              <span>{systemName}</span>
              {typeof kill.total_value === 'number' && (
                <span className="text-green-400">{Math.round(kill.total_value).toLocaleString()} ISK</span>
              )}
              {formattedTime && <span>{formattedTime}</span>}
            </div>
          </div>
        </div>
      </div>
    );
  }
};
