import { SignatureGroup, SystemSignature } from '@/hooks/Mapper/types';
import { parseSignatureCustomInfo } from '@/hooks/Mapper/helpers/parseSignatureCustomInfo';
import { MassState, TimeStatus } from '@/hooks/Mapper/types/connection';
import { getSystemClassGroup } from '@/hooks/Mapper/components/map/helpers/getSystemClassGroup';
import { WormholeDataRaw } from '@/hooks/Mapper/types/wormholes';
import {
  WORMHOLES_ADDITIONAL_INFO,
  SHIP_MASSES_SIZE,
  SHIP_SIZES_NAMES_SHORT,
} from '@/hooks/Mapper/components/map/constants';
import { ALL_DEST_TYPES_MAP, MULTI_DEST_WHS } from '@/hooks/Mapper/constants';
import { ShipSizeStatus } from '@/hooks/Mapper/types/connection';

const getTimeStatusString = (status?: TimeStatus, mapping?: Record<string, string>): string => {
  switch (status) {
    case TimeStatus._1h:
      return mapping?.time_1h !== undefined ? mapping.time_1h : '1H';
    case TimeStatus._4h:
      return mapping?.time_4h !== undefined ? mapping.time_4h : '4H';
    case TimeStatus._4h30m:
      return mapping?.time_4h30m !== undefined ? mapping.time_4h30m : '4.5H';
    case TimeStatus._16h:
      return mapping?.time_16h !== undefined ? mapping.time_16h : '16H';
    case TimeStatus._24h:
      return mapping?.time_24h !== undefined ? mapping.time_24h : '';
    case TimeStatus._48h:
      return mapping?.time_48h !== undefined ? mapping.time_48h : '';
    default:
      return '';
  }
};

const getMassStatusString = (status?: MassState, mapping?: Record<string, string>): string => {
  switch (status) {
    case MassState.normal:
      return mapping?.mass_normal !== undefined ? mapping.mass_normal : '';
    case MassState.half:
      return mapping?.mass_half !== undefined ? mapping.mass_half : 'Destab';
    case MassState.verge:
      return mapping?.mass_verge !== undefined ? mapping.mass_verge : 'Crit';
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
  'c4/c5': 'C4/C5',
};

const formatDestString = (dest: string | null | undefined, mapping?: Record<string, string>): string => {
  if (!dest) return '?';
  const lowerDest = dest.toLowerCase();

  const normalizedDest = DEST_CLASS_OVERRIDES[lowerDest] ? DEST_CLASS_OVERRIDES[lowerDest].toLowerCase() : lowerDest;
  const mappingKey = `class_${normalizedDest.replace(/[^a-z0-9]/g, '')}`;
  if (mapping && mapping[mappingKey] !== undefined) {
    return mapping[mappingKey];
  }

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
  separator: string = '',
): { index: number; chained: string; chainedLetters: string } => {
  let parentBookmarkIndex: string | undefined;
  let parentBookmarkIndexLetters: string | undefined;

  for (const [sysId, sigs] of Object.entries(systemSignatures)) {
    if (sysId === currentSystemUuid || sysId === currentSolarSystemId) continue;

    const parentSigs = sigs.filter(sig => sig.linked_system?.solar_system_id?.toString() === currentSolarSystemId);
    for (const parentSig of parentSigs) {
      const parentInfo = parseSignatureCustomInfo(parentSig.custom_info);

      // Return holes have their bookmark_index deleted, so we skip them to avoid hijacking the chain
      if (parentInfo.bookmark_index === undefined) continue;

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
        if (
          !parentBookmarkIndexLetters ||
          String(parentInfo.bookmark_index_chained_letters).length < parentBookmarkIndexLetters.length
        ) {
          parentBookmarkIndexLetters = String(parentInfo.bookmark_index_chained_letters);
        }
      }
    }
  }

  const currentSigsRaw = [
    ...(systemSignatures[currentSystemUuid] || []),
    ...(systemSignatures[currentSolarSystemId] || []),
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

  const chained = parentBookmarkIndex !== undefined ? `${parentBookmarkIndex}${separator}${i}` : `${i}`;
  const chainedLetters =
    parentBookmarkIndexLetters !== undefined
      ? `${parentBookmarkIndexLetters}${separator}${i}`
      : numberToLetters(i, startAtZero);

  return { index: i, chained, chainedLetters };
};

export const formatBookmarkName = (
  formatStr: string,
  signature: SystemSignature,
  destSystemClass: string | null,
  bookmarkIndex: number | string,
  wormholesData: Record<string, WormholeDataRaw> = {},
  startAtZero: boolean = false,
  mapping?: Record<string, string>,
  systemSignatures?: Record<string, SystemSignature[]>,
  currentSystemId?: string,
  currentSolarSystemId?: string,
): string => {
  let result = formatStr;
  const info = parseSignatureCustomInfo(signature.custom_info);

  // Replace {index}
  result = result.replace(/\{index\}/g, () => bookmarkIndex.toString());

  // Replace {chain_index}
  result = result.replace(/\{chain_index\}/g, () => info.bookmark_index_chained || bookmarkIndex.toString());

  // Replace {index_letter}
  result = result.replace(/\{index_letter\}/g, () =>
    typeof bookmarkIndex === 'number' ? numberToLetters(bookmarkIndex, startAtZero) : bookmarkIndex.toString(),
  );

  // Replace {chain_index_letters}
  result = result.replace(
    /\{chain_index_letters\}/g,
    () =>
      info.bookmark_index_chained_letters ||
      info.bookmark_index_chained ||
      (typeof bookmarkIndex === 'number' ? numberToLetters(bookmarkIndex, startAtZero) : bookmarkIndex.toString()),
  );

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
  const finalDestTypeStr = formatDestString(destTypeStr, mapping);
  result = result.replace(/\{dest_type\}/g, () => (finalDestTypeStr !== '?' ? finalDestTypeStr : ''));

  // Calculate {dest_class_index}
  let destClassIndexStr = '';
  if (
    result.includes('{dest_class_index}') &&
    systemSignatures &&
    (currentSystemId || currentSolarSystemId) &&
    destTypeStr
  ) {
    const currentSigsRaw = [
      ...(systemSignatures[currentSystemId || ''] || []),
      ...(systemSignatures[currentSolarSystemId || ''] || []),
    ];
    // Deduplicate and ensure current signature is included
    const sigsMap = new Map(currentSigsRaw.map(sig => [sig.eve_id, sig]));
    sigsMap.set(signature.eve_id, signature);
    const sigsInSystem = Array.from(sigsMap.values());

    // Helper to get a simplified comparable class for a signature
    const getSigDestClass = (sig: SystemSignature) => {
      if (sig.eve_id === signature.eve_id) return finalDestTypeStr;

      const sigInfo = parseSignatureCustomInfo(sig.custom_info);
      let sDestTypeStr = '';
      if (sig.type && MULTI_DEST_WHS.includes(sig.type) && sigInfo.destType) {
        const destOption = ALL_DEST_TYPES_MAP[sigInfo.destType];
        if (destOption) sDestTypeStr = destOption.label;
      } else if (sig.type === 'K162' && sigInfo.k162Type) {
        const k162Option = ALL_DEST_TYPES_MAP[sigInfo.k162Type];
        if (k162Option) sDestTypeStr = k162Option.label;
      } else if (sig.type && wormholesData[sig.type]) {
        const whData = wormholesData[sig.type];
        const whClass = whData?.dest?.length === 1 ? WORMHOLES_ADDITIONAL_INFO[whData.dest[0]] : null;
        if (whClass) sDestTypeStr = whClass.shortName || whClass.shortTitle;
      } else if (sigInfo.destType) {
        const destOption = ALL_DEST_TYPES_MAP[sigInfo.destType];
        sDestTypeStr = destOption ? destOption.label : sigInfo.destType;
      }
      return formatDestString(sDestTypeStr, mapping);
    };

    const sameClassSigs = sigsInSystem.filter(s => {
      if (s.group !== SignatureGroup.Wormhole) return false;
      return getSigDestClass(s) === finalDestTypeStr;
    });

    // Sort by eve_id to ensure consistent ordering across clients
    sameClassSigs.sort((a, b) => a.eve_id.localeCompare(b.eve_id));

    const indexInClass = sameClassSigs.findIndex(s => s.eve_id === signature.eve_id);
    if (indexInClass > 0 || (indexInClass === 0 && sameClassSigs.length > 1)) {
      destClassIndexStr = String.fromCharCode(97 + indexInClass); // 0->a, 1->b, 2->c...
    }
  }
  result = result.replace(/\{dest_class_index\}/g, () => destClassIndexStr);

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
      const defaultSizeNames: Record<ShipSizeStatus, string> = {
        [ShipSizeStatus.small]: 'S',
        [ShipSizeStatus.medium]: 'M',
        [ShipSizeStatus.large]: '',
        [ShipSizeStatus.freight]: 'XL',
        [ShipSizeStatus.capital]: 'C',
      };
      const sizeMappingKeys: Record<ShipSizeStatus, string> = {
        [ShipSizeStatus.small]: 'size_small',
        [ShipSizeStatus.medium]: 'size_medium',
        [ShipSizeStatus.large]: 'size_large',
        [ShipSizeStatus.freight]: 'size_freight',
        [ShipSizeStatus.capital]: 'size_capital',
      };
      const mappingKey = sizeMappingKeys[sizeStatus];
      if (mapping && mapping[mappingKey] !== undefined) {
        sizeStr = mapping[mappingKey];
      } else {
        sizeStr = defaultSizeNames[sizeStatus] ?? SHIP_SIZES_NAMES_SHORT[sizeStatus] ?? '';
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
  result = result.replace(/\{time_status\}/g, () => getTimeStatusString(info.time_status, mapping));

  // Replace {mass_status} -> Parsed from custom_info.mass_status
  result = result.replace(/\{mass_status\}/g, () => getMassStatusString(info.mass_status, mapping));

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
  targetSystemClassGroup: string | null,
  targetSystemUuid?: string,
  targetSolarSystemId?: string,
): Promise<{ updatedSignature: SystemSignature; shouldUpdate: boolean }> => {
  let updatedSignature = signature;
  let shouldUpdate = false;

  if (
    signature.group !== SignatureGroup.Wormhole ||
    (!currentSettings?.bookmark_name_format && !currentSettings?.bookmark_auto_temp_name)
  ) {
    return { updatedSignature, shouldUpdate };
  }

  const info = parseSignatureCustomInfo(signature.custom_info);
  let bookmarkIndex = info.bookmark_index;
  let bookmarkIndexToUse: number | string = bookmarkIndex != null ? bookmarkIndex : '';

  let isReturnHole = false;
  let symbol = '';

  if (currentSettings?.bookmark_return_hole_ignore && (targetSystemUuid || targetSolarSystemId)) {
    const targetSigsRaw = [
      ...(targetSystemUuid ? systemSignatures[targetSystemUuid] || [] : []),
      ...(targetSolarSystemId ? systemSignatures[targetSolarSystemId] || [] : []),
    ];

    const uniqueTargetSigs = Array.from(new Map(targetSigsRaw.map(sig => [sig.eve_id, sig])).values());

    isReturnHole = uniqueTargetSigs.some(
      sig => sig.linked_system?.solar_system_id?.toString() === currentSolarSystemId.toString(),
    );

    if (isReturnHole) {
      symbol = currentSettings.bookmark_return_hole_symbol || '';
      if (symbol === ' ') symbol = '';
    }
  }

  if (isReturnHole) {
    if (info.bookmark_index !== undefined) {
      delete info.bookmark_index;
    }
    info.bookmark_index_chained = symbol;
    info.bookmark_index_chained_letters = symbol;
    bookmarkIndexToUse = symbol;
    updatedSignature = { ...signature, custom_info: JSON.stringify(info) };
    shouldUpdate = true;
  } else if (bookmarkIndex == null) {
    const separator = currentSettings?.bookmark_custom_mapping?.chain_separator || '';
    const calculated = calculateBookmarkIndex(
      systemSignatures,
      currentSystemId,
      currentSolarSystemId,
      signature.eve_id,
      currentSettings?.bookmark_wormholes_start_at_zero,
      separator,
    );
    bookmarkIndex = calculated.index;
    info.bookmark_index = calculated.index;
    info.bookmark_index_chained = calculated.chained;
    info.bookmark_index_chained_letters = calculated.chainedLetters;
    bookmarkIndexToUse = calculated.index;
    updatedSignature = { ...signature, custom_info: JSON.stringify(info) };
    shouldUpdate = true;
  }

  const needsTempNameUpdate =
    !updatedSignature.temporary_name ||
    (isReturnHole && updatedSignature.temporary_name !== symbol && currentSettings?.bookmark_auto_temp_name);

  if (currentSettings?.bookmark_auto_temp_name && needsTempNameUpdate) {
    let autoName = '';
    switch (currentSettings.bookmark_auto_temp_name) {
      case 'index':
        autoName = bookmarkIndexToUse.toString();
        break;
      case 'index_letter':
        autoName =
          typeof bookmarkIndexToUse === 'number'
            ? numberToLetters(bookmarkIndexToUse, currentSettings.bookmark_wormholes_start_at_zero)
            : bookmarkIndexToUse.toString();
        break;
      case 'chain_index':
        autoName = info.bookmark_index_chained || bookmarkIndexToUse.toString();
        break;
      case 'chain_index_letters':
        autoName = info.bookmark_index_chained_letters || info.bookmark_index_chained || bookmarkIndexToUse.toString();
        break;
    }
    if (autoName !== '' || isReturnHole) {
      updatedSignature = { ...updatedSignature, temporary_name: autoName };
      shouldUpdate = true;
    }
  }

  if (currentSettings?.bookmark_name_format && currentSettings?.bookmark_auto_copy !== false) {
    const formattedStr = formatBookmarkName(
      currentSettings.bookmark_name_format,
      updatedSignature,
      targetSystemClassGroup,
      bookmarkIndexToUse,
      wormholesData,
      currentSettings.bookmark_wormholes_start_at_zero,
      currentSettings.bookmark_custom_mapping,
      systemSignatures,
      currentSystemId,
      currentSolarSystemId,
    );

    // Run this synchronously to avoid clipboard issues if possible
    await copyToClipboard(formattedStr);
  }

  return { updatedSignature, shouldUpdate };
};
