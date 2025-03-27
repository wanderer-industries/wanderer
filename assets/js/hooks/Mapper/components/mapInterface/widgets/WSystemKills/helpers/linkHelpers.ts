const ZKILL_URL = 'https://zkillboard.com';
import { getEveImageUrl } from '@/hooks/Mapper/helpers';

export function zkillLink(type: 'kill' | 'character' | 'corporation' | 'alliance', id?: number | null): string {
  if (!id) return `${ZKILL_URL}`;
  if (type === 'kill') return `${ZKILL_URL}/kill/${id}/`;
  if (type === 'character') return `${ZKILL_URL}/character/${id}/`;
  if (type === 'corporation') return `${ZKILL_URL}/corporation/${id}/`;
  if (type === 'alliance') return `${ZKILL_URL}/alliance/${id}/`;
  return `${ZKILL_URL}`;
}

export const eveImageUrl = getEveImageUrl;

export function buildVictimImageUrls(args: {
  victim_char_id?: number | null;
  victim_ship_type_id?: number | null;
  victim_corp_id?: number | null;
  victim_alliance_id?: number | null;
}) {
  const { victim_char_id, victim_ship_type_id, victim_corp_id, victim_alliance_id } = args;

  const victimPortraitUrl = eveImageUrl('characters', victim_char_id, 'portrait', 64);
  const victimShipUrl = eveImageUrl('types', victim_ship_type_id, 'render', 64);
  const victimCorpLogoUrl = eveImageUrl('corporations', victim_corp_id, 'logo', 32);
  const victimAllianceLogoUrl = eveImageUrl('alliances', victim_alliance_id, 'logo', 32);

  return {
    victimPortraitUrl,
    victimShipUrl,
    victimCorpLogoUrl,
    victimAllianceLogoUrl,
  };
}

export function buildAttackerShipUrl(final_blow_ship_type_id?: number | null): string | null {
  return eveImageUrl('types', final_blow_ship_type_id, 'render', 64);
}

export function buildAttackerImageUrls(args: {
  final_blow_char_id?: number | null;
  final_blow_corp_id?: number | null;
  final_blow_alliance_id?: number | null;
}) {
  const { final_blow_char_id, final_blow_corp_id, final_blow_alliance_id } = args;

  const attackerPortraitUrl = eveImageUrl('characters', final_blow_char_id, 'portrait', 64);
  const attackerCorpLogoUrl = eveImageUrl('corporations', final_blow_corp_id, 'logo', 32);
  const attackerAllianceLogoUrl = eveImageUrl('alliances', final_blow_alliance_id, 'logo', 32);

  return {
    attackerPortraitUrl,
    attackerCorpLogoUrl,
    attackerAllianceLogoUrl,
  };
}

export function getPrimaryLogoAndTooltip(
  allianceUrl: string | null,
  corpUrl: string | null,
  allianceName: string,
  corpName: string,
  fallback: string,
) {
  let url: string | null = null;
  let tooltip = '';

  if (allianceUrl) {
    url = allianceUrl;
    tooltip = allianceName || fallback;
  } else if (corpUrl) {
    url = corpUrl;
    tooltip = corpName || fallback;
  }

  return { url, tooltip };
}

export function getAttackerPrimaryImageAndTooltip(
  isNpc: boolean,
  allianceUrl: string | null,
  corpUrl: string | null,
  allianceName: string,
  corpName: string,
  finalBlowShipTypeId: number | null,
  npcFallback: string = 'NPC Attacker',
) {
  if (isNpc) {
    const shipUrl = buildAttackerShipUrl(finalBlowShipTypeId);
    return {
      url: shipUrl,
      tooltip: npcFallback,
    };
  }

  return getPrimaryLogoAndTooltip(allianceUrl, corpUrl, allianceName, corpName, 'Attacker');
}
