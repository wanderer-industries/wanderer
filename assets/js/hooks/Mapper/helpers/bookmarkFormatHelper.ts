import { SignatureGroup, SystemSignature } from '@/hooks/Mapper/types';
import { parseSignatureCustomInfo } from '@/hooks/Mapper/helpers/parseSignatureCustomInfo';
import { MassState, TimeStatus } from '@/hooks/Mapper/types/connection';
import { getSystemClassGroup } from '@/hooks/Mapper/components/map/helpers/getSystemClassGroup';
import { WormholeDataRaw } from '@/hooks/Mapper/types/wormholes';
import { WORMHOLES_ADDITIONAL_INFO, SHIP_MASSES_SIZE, SHIP_SIZES_NAMES_SHORT } from '@/hooks/Mapper/components/map/constants';
import { ALL_DEST_TYPES_MAP, MULTI_DEST_WHS } from '@/hooks/Mapper/constants';
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
  hs: 'HS',
  'hi-sec': 'HS',
  l: 'LS',
  ls: 'LS',
  'low-sec': 'LS',
  n: 'NS',
  ns: 'NS',
  'null-sec': 'NS',
  t: 'Thera',
  thera: 'Thera',
  d: 'Drifter',
  drifter: 'Drifter',
  p: 'Pochven',
  pochven: 'Pochven',
  'c1/c2/c3': 'C1/C2/C3',
  'c4/c5': 'C4/C5'
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

export const numberToLetters = (num: number, startAtZero: boolean = false): string => {
  if (startAtZero) {
    num += 1;
  }
  let letters = '';
  while (num > 0) {
    const mod = (num - 1) % 26;
    letters = String.fromCharCode(65 + mod) + letters;
    num = Math.floor((num - mod) / 26);
  }
  return letters;
};

export const calculateBookmarkIndex = (
  systemSignatures: Record<string, SystemSignature[]>,
  currentSystemUuid: string,
  currentSolarSystemId: string,
  currentEveId: string,
  startAtZero: boolean = false,
): { index: number; chained: string; chainedLetters: string } => {
  let parentBookmarkIndex: string | undefined;
  let parentBookmarkIndexLetters: string | undefined;

  for (const [sysId, sigs] of Object.entries(systemSignatures)) {
    if (sysId === currentSystemUuid || sysId === currentSolarSystemId) continue;

    const parentSigs = sigs.filter(sig => sig.linked_system?.solar_system_id?.toString() === currentSolarSystemId);
    for (const parentSig of parentSigs) {
      const parentInfo = parseSignatureCustomInfo(parentSig.custom_info);
      if (parentInfo.bookmark_index_chained != null) {
        if (!parentBookmarkIndex || String(parentInfo.bookmark_index_chained).length < parentBookmarkIndex.length) {
          parentBookmarkIndex = String(parentInfo.bookmark_index_chained);
        }
      } else if (parentInfo.bookmark_index != null) {
        if (!parentBookmarkIndex || String(parentInfo.bookmark_index).length < parentBookmarkIndex.length) {
          parentBookmarkIndex = String(parentInfo.bookmark_index);
        }
      }

      if (parentInfo.bookmark_index_chained_letters != null) {
        if (!parentBookmarkIndexLetters || String(parentInfo.bookmark_index_chained_letters).length < parentBookmarkIndexLetters.length) {
          parentBookmarkIndexLetters = String(parentInfo.bookmark_index_chained_letters);
        }
      }
    }
  }

  const currentSigsRaw = [
    ...(systemSignatures[currentSystemUuid] || []),
    ...(systemSignatures[currentSolarSystemId] || [])
  ];

  // Deduplicate in case both keys map to the same or overlapping arrays
  const uniqueCurrentSigs = Array.from(new Map(currentSigsRaw.map(sig => [sig.eve_id, sig])).values());

  const existingIndices = uniqueCurrentSigs
    .filter(sig => sig.eve_id !== currentEveId)
    .map(sig => parseSignatureCustomInfo(sig.custom_info).bookmark_index)
    .filter((i): i is number => typeof i === 'number' && i >= 0);

  let i = startAtZero ? 0 : 1;
  while (existingIndices.includes(i)) {
    i++;
  }

  const chained = parentBookmarkIndex !== undefined ? `${parentBookmarkIndex}${i}` : `${i}`;
  const chainedLetters = parentBookmarkIndexLetters !== undefined ? `${parentBookmarkIndexLetters}${i}` : numberToLetters(i, startAtZero);

  return { index: i, chained, chainedLetters };
};

export const formatBookmarkName = (
  formatStr: string,
  signature: SystemSignature,
  destSystemClass: string | null,
  bookmarkIndex: number,
  wormholesData: Record<string, WormholeDataRaw> = {},
  startAtZero: boolean = false,
): string => {
  let result = formatStr;
  const info = parseSignatureCustomInfo(signature.custom_info);

  // Replace {index}
  result = result.replace(/\{index\}/g, () => bookmarkIndex.toString());

  // Replace {chain_index}
  result = result.replace(/\{chain_index\}/g, () => info.bookmark_index_chained || bookmarkIndex.toString());

  // Replace {index_letter}
  result = result.replace(/\{index_letter\}/g, () => numberToLetters(bookmarkIndex, startAtZero));

  // Replace {chain_index_letters}
  result = result.replace(/\{chain_index_letters\}/g, () => info.bookmark_index_chained_letters || info.bookmark_index_chained || bookmarkIndex.toString());

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
  } else if (signature.type && MULTI_DEST_WHS.includes(signature.type) && info.destType) {
    const destOption = ALL_DEST_TYPES_MAP[info.destType];
    if (destOption) {
      destTypeStr = destOption.label;
    }
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
  
  if (signature.type && MULTI_DEST_WHS.includes(signature.type) && info.destType) {
    const destOption = ALL_DEST_TYPES_MAP[info.destType];
    if (destOption && destOption.whClassName) {
      const whName = destOption.whClassName.split('_')[0];
      whDataForSize = wormholesData[whName];
    }
  } else if (signature.type === 'K162' && info.k162Type) {
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

export const handleAutoBookmark = async (
  signature: SystemSignature,
  currentSettings: any,
  systemSignatures: Record<string, SystemSignature[]>,
  currentSystemId: string,
  currentSolarSystemId: string,
  wormholesData: Record<string, WormholeDataRaw>,
  targetSystemClassGroup: string | null
): Promise<{ updatedSignature: SystemSignature; shouldUpdate: boolean }> => {
  let updatedSignature = signature;
  let shouldUpdate = false;

  if (signature.group !== SignatureGroup.Wormhole || (!currentSettings?.bookmark_name_format && !currentSettings?.bookmark_auto_temp_name)) {
    return { updatedSignature, shouldUpdate };
  }

  const info = parseSignatureCustomInfo(signature.custom_info);
  let bookmarkIndex = info.bookmark_index;

  if (bookmarkIndex == null) {
    const calculated = calculateBookmarkIndex(
      systemSignatures,
      currentSystemId,
      currentSolarSystemId,
      signature.eve_id,
      currentSettings?.bookmark_wormholes_start_at_zero,
    );
    bookmarkIndex = calculated.index;
    info.bookmark_index = calculated.index;
    info.bookmark_index_chained = calculated.chained;
    info.bookmark_index_chained_letters = calculated.chainedLetters;
    updatedSignature = { ...signature, custom_info: JSON.stringify(info) };
    shouldUpdate = true;
  }

  if (currentSettings?.bookmark_auto_temp_name && !updatedSignature.temporary_name) {
    let autoName = '';
    switch (currentSettings.bookmark_auto_temp_name) {
      case 'index':
        autoName = bookmarkIndex.toString();
        break;
      case 'index_letter':
        autoName = numberToLetters(bookmarkIndex, currentSettings.bookmark_wormholes_start_at_zero);
        break;
      case 'chain_index':
        autoName = info.bookmark_index_chained || bookmarkIndex.toString();
        break;
      case 'chain_index_letters':
        autoName = info.bookmark_index_chained_letters || info.bookmark_index_chained || bookmarkIndex.toString();
        break;
    }
    if (autoName) {
      updatedSignature = { ...updatedSignature, temporary_name: autoName };
      shouldUpdate = true;
    }
  }

  if (currentSettings?.bookmark_name_format && currentSettings?.bookmark_auto_copy !== false) {
    const formattedStr = formatBookmarkName(
      currentSettings.bookmark_name_format,
      updatedSignature,
      targetSystemClassGroup,
      bookmarkIndex,
      wormholesData,
      currentSettings.bookmark_wormholes_start_at_zero
    );

    // Run this synchronously to avoid clipboard issues if possible
    await copyToClipboard(formattedStr);
  }

  return { updatedSignature, shouldUpdate };
};
