import { emitMapEvent } from '@/hooks/Mapper/events';
import { SystemView, TimeAgo, TooltipPosition, WdImgButton, WdKillParticipant } from '@/hooks/Mapper/components/ui-kit';
import {
  buildAttackerImageUrls,
  buildAttackerShipUrl,
  buildVictimImageUrls,
  formatISK,
  zkillLink,
} from '@/hooks/Mapper/components/mapInterface/widgets/WSystemKills/helpers';
import { Commands } from '@/hooks/Mapper/types';
import { DetailedKill } from '@/hooks/Mapper/types/kills.ts';

export interface KillNotificationContentProps {
  kill: DetailedKill;
  systemId: string;
}

const getAffiliation = (allianceTicker?: string, corporationTicker?: string) => {
  return allianceTicker || corporationTicker || 'No ticker';
};

const getAttackerName = (kill: DetailedKill) => {
  if (kill.final_blow_char_name) {
    return kill.final_blow_char_name;
  }

  if (kill.npc) {
    return 'NPC';
  }

  return 'Unknown attacker';
};

const getAttackerCountLabel = (attackerCount: number) => {
  if (attackerCount === 0) {
    return 'Unknown count';
  }

  const suffix = attackerCount === 1 ? '' : 's';
  return `${attackerCount} attacker${suffix}`;
};

const getAffiliationLink = (allianceId?: number | null, corporationId?: number | null) => {
  if (allianceId) {
    return zkillLink('alliance', allianceId);
  }

  if (corporationId) {
    return zkillLink('corporation', corporationId);
  }

  return undefined;
};

const getCharacterLink = (characterId?: number | null) => {
  if (!characterId) {
    return undefined;
  }

  return zkillLink('character', characterId);
};

export const KillNotificationContent = ({ kill, systemId }: KillNotificationContentProps) => {
  const { victimPortraitUrl, victimShipUrl, victimCorpLogoUrl, victimAllianceLogoUrl } = buildVictimImageUrls(kill);
  const { attackerPortraitUrl, attackerCorpLogoUrl, attackerAllianceLogoUrl } = buildAttackerImageUrls(kill);
  const attackerShipUrl = buildAttackerShipUrl(kill.final_blow_ship_type_id);
  const victimLogoUrl = victimAllianceLogoUrl || victimCorpLogoUrl;
  const attackerLogoUrl = attackerAllianceLogoUrl || attackerCorpLogoUrl;
  const victimTicker = getAffiliation(kill.victim_alliance_ticker, kill.victim_corp_ticker);
  const attackerAffiliationName = kill.final_blow_alliance_name || kill.final_blow_corp_name || 'Unknown affiliation';
  const attackerCount = kill.attacker_count ?? 0;
  const attackerCountLabel = getAttackerCountLabel(attackerCount);
  const killValue = kill.total_value ? `${formatISK(kill.total_value)} ISK` : 'Unknown value';
  const killLink = zkillLink('kill', kill.killmail_id);
  const victimCharacterLink = getCharacterLink(kill.victim_char_id);
  const victimAffiliationLink = getAffiliationLink(kill.victim_alliance_id, kill.victim_corp_id);
  const attackerCharacterLink = getCharacterLink(kill.final_blow_char_id);
  const attackerAffiliationLink = getAffiliationLink(kill.final_blow_alliance_id, kill.final_blow_corp_id);

  const handleNavigateToSystem = () => {
    emitMapEvent({ name: Commands.centerSystem, data: systemId });
  };

  return (
    <div className="min-w-0 flex-1 pr-1 text-stone-200">
      <div className="pr-8">
        <div className="flex items-baseline gap-2">
          <div className="text-sm font-semibold text-stone-100">Kill activity</div>
          {kill.kill_time && <TimeAgo timestamp={kill.kill_time} className="text-xs font-normal text-stone-500" />}
          {!kill.kill_time && <span className="text-xs font-normal text-stone-500">Just now</span>}
        </div>
      </div>

      <div className="grid grid-cols-2 gap-3 py-3">
        <WdKillParticipant
          role="Victim"
          value={killValue}
          valueClassName="font-medium text-emerald-400"
          primaryImageUrl={victimShipUrl}
          primaryImageAlt="Victim ship"
          primaryImageHref={killLink}
          secondaryImageUrl={victimPortraitUrl}
          secondaryImageAlt="Victim portrait"
          secondaryImageHref={victimCharacterLink}
          secondaryImageFit="cover"
          title={kill.victim_ship_name || 'Unknown ship'}
          titleHref={killLink}
          subtitle={victimTicker}
          subtitleHref={victimAffiliationLink}
          subtitleImageUrl={victimLogoUrl}
          subtitleImageAlt="Victim affiliation"
          detail={kill.victim_char_name || 'Unknown pilot'}
          detailHref={victimCharacterLink}
        />

        <WdKillParticipant
          className="border-l border-stone-700/70 pl-3"
          role="Attacker"
          value={attackerCountLabel}
          valueClassName="text-stone-500"
          primaryImageUrl={attackerLogoUrl}
          primaryImageAlt="Attacker affiliation"
          primaryImageHref={attackerAffiliationLink}
          secondaryImageUrl={attackerShipUrl}
          secondaryImageAlt="Final blow ship"
          secondaryImageHref={killLink}
          title={attackerAffiliationName}
          titleHref={attackerAffiliationLink}
          subtitle={getAttackerName(kill)}
          subtitleHref={attackerCharacterLink}
          subtitleImageUrl={attackerPortraitUrl}
          subtitleImageAlt="Final blow pilot"
          detail={kill.final_blow_ship_name || 'Unknown ship'}
        />
      </div>

      <div className="flex items-center justify-between gap-2 border-t border-stone-800/80 pt-2">
        <div className="flex min-w-0 items-center gap-2 text-[0.7rem]">
          <SystemView systemId={kill.solar_system_id.toString()} showCustomName hideRegion compact />
          <WdImgButton
            className="pi-compass !flex h-4 w-4 !items-center justify-center leading-none text-sky-400 hover:text-sky-300"
            onClick={handleNavigateToSystem}
            tooltip={{ content: 'Center map on this system', position: TooltipPosition.top }}
          />
        </div>
        <div className="flex shrink-0 items-center text-[0.7rem]">
          <a
            href={zkillLink('kill', kill.killmail_id)}
            target="_blank"
            rel="noopener noreferrer"
            className="inline-flex items-center gap-1.5 text-stone-400 hover:text-stone-200"
          >
            Open killmail
            <i className="pi pi-external-link text-[0.6rem]" aria-hidden="true" />
          </a>
        </div>
      </div>
    </div>
  );
};
