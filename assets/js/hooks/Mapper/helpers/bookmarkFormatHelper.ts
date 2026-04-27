import { SignatureGroup, SystemSignature } from '@/hooks/Mapper/types';
import { parseSignatureCustomInfo } from '@/hooks/Mapper/helpers/parseSignatureCustomInfo';
import { MassState, TimeStatus } from '@/hooks/Mapper/types/connection';
import { getSystemClassGroup } from '@/hooks/Mapper/components/map/helpers/getSystemClassGroup';
import { WormholeDataRaw } from '@/hooks/Mapper/types/wormholes';
import { WORMHOLES_ADDITIONAL_INFO, SHIP_MASSES_SIZE, SHIP_SIZES_NAMES_SHORT } from '@/hooks/Mapper/components/map/constants';
import { ALL_DEST_TYPES_MAP } from '@/hooks/Mapper/constants';
import { ShipSizeStatus } from '@/hooks/Mapper/types/connection';

const getTimeStatusString = (status?: TimeStatus): string => {
  switch (status) {
    case TimeStatus._1h:
      return 'EoL'; // Or '1H', standard EVE mapping tends to use EoL for 1H
    case TimeStatus._4h:
      return '4H';
    case TimeStatus._4h30m:
      return '4.5H';
    case TimeStatus._16h:
      return '16H';
    case TimeStatus._24h:
      return '';
    case TimeStatus._48h:
      return '';
    default:
      return '';
  }
};

const getMassStatusString = (status?: MassState): string => {
  switch (status) {
    case MassState.normal:
      return ''; // Typically not specified if normal
    case MassState.half:
      return 'Destab';
    case MassState.verge:
      return 'Crit';
    default:
      return '';
  }
};

const DEST_CLASS_OVERRIDES: Record<string, string> = {
  h: 'HS',
  l: 'LS',
  n: 'NS',
  t: 'Thera',
  d: 'Drifter',
  p: 'Pochven'
};

const formatDestString = (dest: string | null | undefined): string => {
  if (!dest) return '?';
  const lowerDest = dest.toLowerCase();
  if (DEST_CLASS_OVERRIDES[lowerDest]) {
    return DEST_CLASS_OVERRIDES[lowerDest];
  }
  if (lowerDest.length <= 3) return dest.toUpperCase();
  return dest.charAt(0).toUpperCase() + dest.slice(1);
};

export const calculateBookmarkIndex = (signatures: SystemSignature[], currentEveId: string): number => {
  const indices = signatures
    .filter(sig => sig.eve_id !== currentEveId)
    .map(sig => {
      const info = parseSignatureCustomInfo(sig.custom_info);
      return info.bookmark_index;
    })
    .filter((i): i is number => typeof i === 'number' && i > 0);

  let i = 1;
  while (indices.includes(i)) {
    i++;
  }
  return i;
};

export const formatBookmarkName = (
  formatStr: string,
  signature: SystemSignature,
  destSystemClass: string | null,
  bookmarkIndex: number,
  wormholesData: Record<string, WormholeDataRaw> = {},
): string => {
  let result = formatStr;
  const info = parseSignatureCustomInfo(signature.custom_info);

  // Replace {i}
  result = result.replace(/\{i\}/g, () => bookmarkIndex.toString());

  // Replace {sig_letters} (first 3 chars of eve_id)
  const sigLetters = signature.eve_id.substring(0, 3).toUpperCase();
  result = result.replace(/\{sig_letters\}/g, () => sigLetters);

  // Replace {sig} (full signature ID)
  const fullSig = signature.eve_id.toUpperCase();
  result = result.replace(/\{sig\}/g, () => fullSig);

  // Replace {dest_type}
  let destTypeStr = '';
  if (destSystemClass) {
    destTypeStr = destSystemClass;
  } else if (signature.type === 'K162' && info.k162Type) {
    const k162Option = ALL_DEST_TYPES_MAP[info.k162Type];
    if (k162Option) {
      destTypeStr = k162Option.label;
    }
  } else if (signature.type && wormholesData[signature.type]) {
    const whData = wormholesData[signature.type];
    const whClass = whData?.dest?.length === 1 ? WORMHOLES_ADDITIONAL_INFO[whData.dest[0]] : null;
    if (whClass) {
      destTypeStr = whClass.shortName || whClass.shortTitle;
    }
  } else if (info.destType) {
    const destOption = ALL_DEST_TYPES_MAP[info.destType];
    destTypeStr = destOption ? destOption.label : info.destType;
  }
  const finalDestTypeStr = formatDestString(destTypeStr);
  result = result.replace(/\{dest_type\}/g, () => (finalDestTypeStr !== '?' ? finalDestTypeStr : ''));

  // Replace {size} and {mass}
  let sizeStr = '';
  let massStr = '';
  let whDataForSize: WormholeDataRaw | null = null;
  if (signature.type === 'K162' && info.k162Type) {
    const k162Option = ALL_DEST_TYPES_MAP[info.k162Type];
    if (k162Option && k162Option.whClassName) {
      const whName = k162Option.whClassName.split('_')[0];
      whDataForSize = wormholesData[whName];
    }
  } else if (signature.type && wormholesData[signature.type]) {
    whDataForSize = wormholesData[signature.type];
  }

  if (whDataForSize) {
    if (whDataForSize.max_mass_per_jump) {
      const sizeStatus = SHIP_MASSES_SIZE[whDataForSize.max_mass_per_jump] ?? ShipSizeStatus.large;
      if (sizeStatus !== ShipSizeStatus.large) {
        sizeStr = SHIP_SIZES_NAMES_SHORT[sizeStatus] || '';
      }
    }
    if (whDataForSize.total_mass) {
      massStr = Number((whDataForSize.total_mass / 1_000_000_000).toFixed(2)).toString();
    }
  }
  result = result.replace(/\{size\}/g, () => sizeStr);
  result = result.replace(/\{mass\}/g, () => massStr);

  // Replace {type} -> signature.type
  result = result.replace(/\{type\}/g, () => signature.type || '');

  // Replace {time_status} -> Parsed from custom_info.time_status
  result = result.replace(/\{time_status\}/g, () => getTimeStatusString(info.time_status));

  // Replace {mass_status} -> Parsed from custom_info.mass_status
  result = result.replace(/\{mass_status\}/g, () => getMassStatusString(info.mass_status));

  // Replace {temporary_name} -> signature.temporary_name
  result = result.replace(/\{temporary_name\}/g, () => signature.temporary_name || '');

  // Replace {description} -> signature.description
  result = result.replace(/\{description\}/g, () => signature.description || '');

  // Cleanup whitespace
  return result.trim().replace(/\s+/g, ' ');
};

export const copyToClipboard = async (text: string) => {
  try {
    await navigator.clipboard.writeText(text);
  } catch (err) {
    console.warn('Failed to copy to clipboard', err);
  }
};
