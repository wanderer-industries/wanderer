const ZKILL_URL = 'https://zkillboard.com';
const BASE_IMAGE_URL = 'https://images.evetech.net';

export function zkillLink(type: 'kill' | 'character' | 'corporation' | 'alliance', id?: number | null): string {
  if (!id) return `${ZKILL_URL}`;
  if (type === 'kill') return `${ZKILL_URL}/kill/${id}/`;
  if (type === 'character') return `${ZKILL_URL}/character/${id}/`;
  if (type === 'corporation') return `${ZKILL_URL}/corporation/${id}/`;
  if (type === 'alliance') return `${ZKILL_URL}/alliance/${id}/`;
  return `${ZKILL_URL}`;
}

export function eveImageUrl(
  category: 'characters' | 'corporations' | 'alliances' | 'types',
  id?: number | null,
  variation: string = 'icon',
  size?: number,
): string | null {
  if (!id || id <= 0) {
    return null;
  }
  let url = `${BASE_IMAGE_URL}/${category}/${id}/${variation}`;
  if (size) {
    url += `?size=${size}`;
  }
  return url;
}

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
