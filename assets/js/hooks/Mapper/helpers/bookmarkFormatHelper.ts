import {
  AutoFormatOption,
  BookmarkCustomMapping,
  BookmarkCustomMappingKey,
  BookmarkFormatVariable,
  CommandLinkSignatureToSystem,
  GetUserSettingsResponse,
  OutCommand,
  OutCommandHandler,
  SignatureGroup,
  SignatureKind,
  SystemSignature,
  UserSettings,
} from '@/hooks/Mapper/types';
import { LabelsManager } from '@/hooks/Mapper/utils/labelsManager.ts';
import { SolarSystemRawType } from '@/hooks/Mapper/types/system';
import { MassState, ShipSizeStatus, SolarSystemConnection, TimeStatus } from '@/hooks/Mapper/types/connection';
import { parseSignatureCustomInfo } from '@/hooks/Mapper/helpers/parseSignatureCustomInfo';
import { WormholeDataRaw } from '@/hooks/Mapper/types/wormholes';
import {
  WORMHOLES_ADDITIONAL_INFO,
  SHIP_MASSES_SIZE,
  SHIP_SIZES_NAMES_SHORT,
} from '@/hooks/Mapper/components/map/constants';
import { ALL_DEST_TYPES_MAP, DEST_TYPES_MAP_MAP, MULTI_DEST_WHS } from '@/hooks/Mapper/constants';
import { getSystemClassGroup } from '@/hooks/Mapper/components/map/helpers/getSystemClassGroup.ts';
import { getSystemStaticInfo } from '@/hooks/Mapper/mapRootProvider/hooks/useLoadSystemStatic';

export const getSystemSolarIdStr = (sys?: SolarSystemRawType | null): string | undefined => {
  if (!sys) return undefined;
  const solarId = sys.system_static_info?.solar_system_id ?? getSystemStaticInfo(sys.id)?.solar_system_id;
  return solarId !== undefined ? solarId.toString() : undefined;
};

export const findSystem = (systems: SolarSystemRawType[] = [], id?: string | null): SolarSystemRawType | undefined => {
  if (!id) return undefined;
  const idStr = id.toString();
  return systems.find(s => s.id === idStr || getSystemSolarIdStr(s) === idStr);
};

export const getReturnHoleSymbol = (settings?: UserSettings | null): string | undefined => {
  if (!settings?.bookmark_return_hole_ignore) return undefined;
  const raw = settings.bookmark_return_hole_symbol?.trim().toLowerCase();
  return raw !== '' ? raw : undefined;
};

export const isReturnHoleSignature = (
  info: { bookmark_index?: number; bookmark_index_chained?: string; bookmark_index_chained_letters?: string },
  temporaryName?: string,
  returnHoleSymbol?: string,
): boolean => {
  const isMarked =
    info.bookmark_index === undefined &&
    (info.bookmark_index_chained !== undefined || info.bookmark_index_chained_letters !== undefined);
  const isSymbolMatch =
    (returnHoleSymbol !== undefined && temporaryName?.trim().toLowerCase() === returnHoleSymbol) ||
    temporaryName?.trim() === '<';
  return isMarked || Boolean(isSymbolMatch);
};

export const hasDifferentActiveLinkedSig = (
  targetSystem: SolarSystemRawType | undefined,
  currentEveId: string,
  systemSignatures: Record<string, SystemSignature[]>,
): boolean => {
  if (!targetSystem?.linked_sig_eve_id || targetSystem.linked_sig_eve_id === currentEveId) {
    return false;
  }
  const targetSolarId = getSystemSolarIdStr(targetSystem);
  return Object.values(systemSignatures)
    .flat()
    .some(
      s =>
        !s.deleted &&
        s.eve_id === targetSystem.linked_sig_eve_id &&
        (s.linked_system?.solar_system_id?.toString() === targetSystem.id ||
          (!!targetSolarId && s.linked_system?.solar_system_id?.toString() === targetSolarId)),
    );
};

export const ensureUserSettings = async (
  userSettings: UserSettings | null,
  outCommand: OutCommandHandler,
): Promise<UserSettings | null> => {
  if (userSettings) return userSettings;
  try {
    const res = await outCommand<GetUserSettingsResponse>({ type: OutCommand.getUserSettings, data: null });
    return res?.user_settings ?? null;
  } catch (e) {
    console.warn('Failed to fetch user settings', e);
    return null;
  }
};

export const resolveSignatureDestType = (
  sig: SystemSignature,
  destSystemClass: string | null | undefined,
  wormholesData: Record<string, Partial<WormholeDataRaw>> = {},
): string => {
  if (destSystemClass) return destSystemClass;
  const info = parseSignatureCustomInfo(sig.custom_info);
  const linkedClassGroup = sig.linked_system?.system_class ? getSystemClassGroup(sig.linked_system.system_class) : null;
  if (linkedClassGroup) return linkedClassGroup;

  if (sig.type && MULTI_DEST_WHS.includes(sig.type) && info.destType) {
    return ALL_DEST_TYPES_MAP[info.destType]?.label || info.destType;
  }
  if (sig.type === 'K162' && info.k162Type) {
    return ALL_DEST_TYPES_MAP[info.k162Type]?.label || info.k162Type;
  }
  if (sig.type && wormholesData[sig.type]) {
    const whData = wormholesData[sig.type];
    const whClass = whData?.dest?.length === 1 ? WORMHOLES_ADDITIONAL_INFO[whData.dest[0]] : null;
    if (whClass) return whClass.shortName || whClass.shortTitle;
  }
  if (info.destType) {
    return ALL_DEST_TYPES_MAP[info.destType]?.label || info.destType;
  }
  return '';
};

const getTimeStatusString = (status?: TimeStatus, mapping?: BookmarkCustomMapping): string => {
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

const getDirectionString = (signatureType: string | undefined, mapping?: BookmarkCustomMapping): string => {
  if (!signatureType) return '';
  if (signatureType === 'K162') {
    return mapping?.direction_incoming !== undefined ? mapping.direction_incoming : 'In';
  }
  return mapping?.direction_outgoing !== undefined ? mapping.direction_outgoing : 'Out';
};

const getSpawnTypeString = (
  signatureType: string | undefined,
  currentSystemStatics: string[] | undefined,
  mapping?: BookmarkCustomMapping,
): string => {
  if (!signatureType) return '';
  if (signatureType === 'K162') {
    return mapping?.spawn_k162 !== undefined ? mapping.spawn_k162 : 'K162';
  }
  if (currentSystemStatics === undefined) return '';
  if (currentSystemStatics.includes(signatureType)) {
    return mapping?.spawn_static !== undefined ? mapping.spawn_static : 'Static';
  }
  return mapping?.spawn_wandering !== undefined ? mapping.spawn_wandering : 'Wandering';
};

const getMassStatusString = (status?: MassState, mapping?: BookmarkCustomMapping): string => {
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

const formatDestString = (dest: string | null | undefined, mapping?: BookmarkCustomMapping): string => {
  if (!dest) return '?';
  const lowerDest = dest.toLowerCase();

  const normalizedDest = DEST_CLASS_OVERRIDES[lowerDest] ? DEST_CLASS_OVERRIDES[lowerDest].toLowerCase() : lowerDest;
  const mappingKey = `class_${normalizedDest.replace(/[^a-z0-9]/g, '')}` as BookmarkCustomMappingKey;
  if (mapping && mapping[mappingKey] !== undefined) {
    return mapping[mappingKey]!;
  }

  if (DEST_CLASS_OVERRIDES[lowerDest]) {
    return DEST_CLASS_OVERRIDES[lowerDest];
  }
  if (lowerDest.length <= 3) return dest.toUpperCase();
  return dest.charAt(0).toUpperCase() + dest.slice(1);
};

export const numberToLetters = (num: number, startAtZero: boolean = false): string => {
  if (startAtZero || num === 0) {
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

export const getLocalChainSystems = (
  startUuid: string,
  systems: SolarSystemRawType[],
  connections: SolarSystemConnection[],
): SolarSystemRawType[] => {
  const visited = new Set<string>();
  const queue = [startUuid];
  visited.add(startUuid);

  const startSys = findSystem(systems, startUuid);
  if (startSys) {
    visited.add(startSys.id);
    const startSolarId = getSystemSolarIdStr(startSys);
    if (startSolarId) visited.add(startSolarId);
  }

  while (queue.length > 0) {
    const current = queue.shift()!;
    const currSys = findSystem(systems, current);
    const currSolarId = getSystemSolarIdStr(currSys);
    const matchesCurrent = (id: string) =>
      id === current || (!!currSys && id === currSys.id) || (!!currSolarId && id === currSolarId);

    const neighbors = connections.filter(
      c => (matchesCurrent(c.source) || matchesCurrent(c.target)) && (c.type === undefined || c.type === 0),
    );

    for (const conn of neighbors) {
      const neighborUuid = matchesCurrent(conn.source) ? conn.target : conn.source;
      const neighborSys = findSystem(systems, neighborUuid);
      const neighborSolarId = getSystemSolarIdStr(neighborSys);
      if (!visited.has(neighborUuid)) {
        visited.add(neighborUuid);
        if (neighborSys) visited.add(neighborSys.id);
        if (neighborSolarId) visited.add(neighborSolarId);
        queue.push(neighborUuid);
      }
    }
  }

  return systems.filter(s => {
    const solarId = getSystemSolarIdStr(s);
    return visited.has(s.id) || (!!solarId && visited.has(solarId));
  });
};

export const isValidBookmarkIndex = (tag: string, separator: string = ''): boolean => {
  const cleaned = tag.trim();
  if (!cleaned) return false;

  const parts = separator ? cleaned.split(separator) : [cleaned];

  return parts.every(part => {
    if (!/^[A-Za-z0-9]+$/.test(part)) return false;
    if (/^\d+$/.test(part)) return true;
    if (/^[A-Za-z]{1,2}\d+$/.test(part)) return true;
    return /^[A-Za-z]{1,2}$/.test(part);
  });
};

const normalizeChainConnections = (
  systems: SolarSystemRawType[],
  rawConnections: SolarSystemConnection[],
  systemSignatures: Record<string, SystemSignature[]>,
  separator: string = '',
  returnHoleSymbol?: string,
): SolarSystemConnection[] => {
  if (!rawConnections || rawConnections.length === 0 || !systems || systems.length === 0) {
    return rawConnections;
  }

  const findSys = (id: string) => findSystem(systems, id);
  const getSigs = (sys?: SolarSystemRawType, idFallback?: string): SystemSignature[] => {
    const solarId = getSystemSolarIdStr(sys);
    const id = sys?.id || idFallback || '';
    return [
      ...(id ? systemSignatures[id] || [] : []),
      ...(solarId && solarId !== id ? systemSignatures[solarId] || [] : []),
    ];
  };
  const hasPrimaryLinkedSigTo = (
    fromSys: SolarSystemRawType | undefined,
    fromId: string,
    toSys: SolarSystemRawType | undefined,
  ): boolean => {
    if (!toSys?.linked_sig_eve_id) return false;
    return getSigs(fromSys, fromId).some(
      sig => !sig.deleted && sig.group === SignatureGroup.Wormhole && sig.eve_id === toSys.linked_sig_eve_id,
    );
  };
  const hasForwardSigTo = (
    fromSys: SolarSystemRawType | undefined,
    fromId: string,
    toSys: SolarSystemRawType | undefined,
    toId: string,
  ): boolean => {
    if (hasPrimaryLinkedSigTo(toSys, toId, fromSys) && !hasPrimaryLinkedSigTo(fromSys, fromId, toSys)) {
      return false;
    }
    const toSolarId = getSystemSolarIdStr(toSys);
    return getSigs(fromSys, fromId).some(sig => {
      if (sig.deleted || sig.group !== SignatureGroup.Wormhole) return false;
      const sInfo = parseSignatureCustomInfo(sig.custom_info);
      if (isReturnHoleSignature(sInfo, sig.temporary_name, returnHoleSymbol)) return false;
      if (toSys?.linked_sig_eve_id && sig.eve_id === toSys.linked_sig_eve_id) return true;
      const linkedId = sig.linked_system?.solar_system_id?.toString();
      return (
        !!linkedId &&
        (linkedId === toId || (!!toSys && linkedId === toSys.id) || (!!toSolarId && linkedId === toSolarId))
      );
    });
  };
  const getValidLabel = (sys?: SolarSystemRawType): string | null => {
    if (!sys) return null;
    const cLabel = sys.labels ? new LabelsManager(sys.labels).customLabel?.trim() : '';
    const tag = sys.tag?.trim() || '';
    const tempName = sys.temporary_name?.trim() || '';
    const cand = [cLabel, tag, tempName].find(
      v => v !== '' && v.toLowerCase() !== returnHoleSymbol && isValidBookmarkIndex(v, separator),
    );
    return cand ?? null;
  };

  let result = rawConnections.map(c => {
    if (c.type !== undefined && c.type !== 0) return c;
    const sSys = findSys(c.source);
    const tSys = findSys(c.target);
    if (!sSys || !tSys) return c;

    const sHasFwdToT = hasForwardSigTo(sSys, c.source, tSys, c.target);
    if (sHasFwdToT) return c;

    const tHasFwdToS = hasForwardSigTo(tSys, c.target, sSys, c.source);
    if (tHasFwdToS) {
      return { ...c, source: c.target, target: c.source };
    }

    const sLabel = getValidLabel(sSys);
    const tLabel = getValidLabel(tSys);

    if (tSys.locked && !tSys.linked_sig_eve_id && !tLabel && !sSys.locked) {
      return { ...c, source: c.target, target: c.source };
    }

    if (sLabel && tLabel) {
      const sDepth = separator ? sLabel.split(separator).length : sLabel.length;
      const tDepth = separator ? tLabel.split(separator).length : tLabel.length;
      if (sDepth > tDepth) {
        const sHasOtherIncoming = rawConnections.some(
          oc =>
            oc !== c &&
            (oc.type === undefined || oc.type === 0) &&
            (oc.target === c.source || oc.target === sSys.id || oc.target === getSystemSolarIdStr(sSys)),
        );
        const tHasOtherConns = rawConnections.some(
          oc =>
            oc !== c &&
            (oc.type === undefined || oc.type === 0) &&
            (oc.source === c.target ||
              oc.target === c.target ||
              oc.source === tSys.id ||
              oc.target === tSys.id ||
              oc.source === getSystemSolarIdStr(tSys) ||
              oc.target === getSystemSolarIdStr(tSys)),
        );
        if (!(sHasOtherIncoming && !tHasOtherConns)) {
          return { ...c, source: c.target, target: c.source };
        }
      }
    }

    return c;
  });

  let changed = true;
  let iterations = 0;
  while (changed && iterations < result.length) {
    changed = false;
    iterations++;
    result = result.map(c => {
      if (c.type !== undefined && c.type !== 0) return c;
      const sSys = findSys(c.source);
      const tSys = findSys(c.target);
      if (!sSys || !tSys) return c;

      if (hasForwardSigTo(sSys, c.source, tSys, c.target) || hasForwardSigTo(tSys, c.target, sSys, c.source)) {
        return c;
      }

      const sLabel = getValidLabel(sSys);
      const tLabel = getValidLabel(tSys);
      const sDepth = sLabel ? (separator ? sLabel.split(separator).length : sLabel.length) : 0;
      const tDepth = tLabel ? (separator ? tLabel.split(separator).length : tLabel.length) : 0;

      const sSolarId = getSystemSolarIdStr(sSys);
      const tSolarId = getSystemSolarIdStr(tSys);

      const sHasOtherConns = result.some(
        oc =>
          oc !== c &&
          (oc.type === undefined || oc.type === 0) &&
          (oc.source === c.source ||
            oc.target === c.source ||
            oc.source === sSys.id ||
            oc.target === sSys.id ||
            (!!sSolarId && (oc.source === sSolarId || oc.target === sSolarId))),
      );

      const tHasIncomingConn = result.some(
        oc =>
          oc !== c &&
          (oc.type === undefined || oc.type === 0) &&
          (oc.target === c.target || oc.target === tSys.id || (!!tSolarId && oc.target === tSolarId)),
      );

      if (
        !sSys.locked &&
        !sHasOtherConns &&
        (tSys.locked || tHasIncomingConn) &&
        (!sLabel || (!!tLabel && sDepth >= tDepth))
      ) {
        changed = true;
        return { ...c, source: c.target, target: c.source };
      }

      return c;
    });
  }

  return result;
};

export const calculateBookmarkIndex = (
  systemSignatures: Record<string, SystemSignature[]>,
  currentSystemUuid: string,
  currentSolarSystemId: string,
  currentEveId: string,
  startAtZero: boolean = false,
  separator: string = '',
  systems: SolarSystemRawType[] = [],
  rawConnections: SolarSystemConnection[] = [],
  currentSettings?: UserSettings | null,
  targetSystemUuid?: string,
): { index: number; chained: string; chainedLetters: string } => {
  let parentBookmarkIndex: string | undefined;
  let parentBookmarkIndexLetters: string | undefined;

  const settings = currentSettings;
  const returnHoleSymbol = getReturnHoleSymbol(settings);
  const connections = normalizeChainConnections(systems, rawConnections, systemSignatures, separator, returnHoleSymbol);

  // Find the chain index of the current system by checking its own label/tag,
  // or tracing its incoming map connections.
  if (systems && systems.length > 0) {
    const toChainPair = (val: string): { indexStr: string; lettersStr: string } => {
      if (/^\d+$/.test(val)) {
        return { indexStr: val, lettersStr: numberToLetters(parseInt(val, 10), startAtZero) };
      }
      if (separator) {
        const parts = val.split(separator);
        if (parts.length > 0 && /^\d+$/.test(parts[0])) {
          const firstLetters = numberToLetters(parseInt(parts[0], 10), startAtZero);
          return { indexStr: val, lettersStr: [firstLetters, ...parts.slice(1)].join(separator) };
        }
      }
      return { indexStr: val, lettersStr: val };
    };

    const normalizeLabelCase = (val: string): string => (/^\d+$/.test(val) ? val : val.toUpperCase());

    const autoModes = [
      settings?.system_auto_tag,
      settings?.system_custom_label_name,
      settings?.bookmark_auto_temp_name,
    ];
    const hasSingleHopAutoMode = !settings || autoModes.some(m => m === 'index' || m === 'index_letter');

    const getOwnValidLabel = (s: SolarSystemRawType, linkedSig?: SystemSignature): string | null => {
      const cLabel = s.labels ? new LabelsManager(s.labels).customLabel?.trim() : '';
      const tag = s.tag?.trim() || '';
      const tempName = s.temporary_name?.trim() || '';

      const validCandidates = [cLabel, tag, tempName]
        .filter(v => v !== '' && v.toLowerCase() !== returnHoleSymbol && isValidBookmarkIndex(v, separator))
        .map(normalizeLabelCase);
      if (validCandidates.length === 0) return null;
      if (validCandidates.length === 1) return validCandidates[0];

      if (linkedSig) {
        const sInfo = parseSignatureCustomInfo(linkedSig.custom_info);
        const allowSingleHopAuto =
          hasSingleHopAutoMode ||
          !sInfo.bookmark_index_chained ||
          (typeof sInfo.bookmark_index === 'number' && sInfo.bookmark_index_chained === String(sInfo.bookmark_index));
        const autoGeneratedVals = new Set(
          [
            sInfo.bookmark_index_chained,
            sInfo.bookmark_index_chained_letters,
            allowSingleHopAuto && typeof sInfo.bookmark_index === 'number' ? String(sInfo.bookmark_index) : undefined,
            allowSingleHopAuto && typeof sInfo.bookmark_index === 'number'
              ? numberToLetters(sInfo.bookmark_index, startAtZero)
              : undefined,
          ]
            .filter((v): v is string => typeof v === 'string' && v !== '')
            .map(normalizeLabelCase),
        );
        const sigTemp = linkedSig.temporary_name?.trim();
        const normSigTemp = sigTemp ? normalizeLabelCase(sigTemp) : undefined;
        if (normSigTemp && !autoGeneratedVals.has(normSigTemp) && validCandidates.includes(normSigTemp)) {
          return normSigTemp;
        }
        const manualOverride = validCandidates.find(v => !autoGeneratedVals.has(v));
        if (manualOverride) {
          return manualOverride;
        }
        if (normSigTemp && validCandidates.includes(normSigTemp)) {
          return normSigTemp;
        }
      } else if (settings?.system_auto_tag || settings?.system_custom_label_name) {
        const isValidCandidate = (val?: string) =>
          !!val && val !== '' && val.toLowerCase() !== returnHoleSymbol && isValidBookmarkIndex(val, separator);
        if (!s.linked_sig_eve_id && isValidCandidate(tempName)) {
          return normalizeLabelCase(tempName);
        }
        if (!settings?.system_auto_tag && settings?.system_custom_label_name && isValidCandidate(tag)) {
          return normalizeLabelCase(tag);
        }
        if (!settings?.system_custom_label_name && settings?.system_auto_tag && isValidCandidate(cLabel)) {
          return normalizeLabelCase(cLabel);
        }
      }

      return validCandidates[0];
    };

    const getSystemChainIndex = (
      targetUuid: string,
      visited: Set<string> = new Set(),
      ignoreManualLabels: boolean = false,
    ): { indexStr: string; lettersStr: string; isCycle?: boolean } | null => {
      if (visited.has(targetUuid)) return { indexStr: '', lettersStr: '', isCycle: true };
      visited.add(targetUuid);

      const sys = findSystem(systems, targetUuid);
      if (!sys) return null;
      const sysSolarId = getSystemSolarIdStr(sys);

      const findLinkedSigForSystem = (
        parentSigs: SystemSignature[],
        targetSys: SolarSystemRawType | undefined,
        targetIdFallback?: string,
      ): SystemSignature | undefined => {
        const validSigs = parentSigs.filter(
          sig =>
            !sig.deleted &&
            parseSignatureCustomInfo(sig.custom_info).bookmark_index !== undefined &&
            (!returnHoleSymbol || sig.temporary_name?.trim().toLowerCase() !== returnHoleSymbol),
        );
        if (targetSys?.linked_sig_eve_id) {
          const byEveId = validSigs.find(sig => sig.eve_id === targetSys.linked_sig_eve_id);
          if (byEveId) return byEveId;
        }
        const targetSolarId = getSystemSolarIdStr(targetSys);
        return validSigs.find(sig => {
          const linkedIdStr = sig.linked_system?.solar_system_id?.toString();
          return (
            !!linkedIdStr &&
            ((!!targetIdFallback && linkedIdStr === targetIdFallback) ||
              (!!targetSys && linkedIdStr === targetSys.id) ||
              (!!targetSolarId && linkedIdStr === targetSolarId))
          );
        });
      };

      const findLinkedSig = (parentSigs: SystemSignature[]): SystemSignature | undefined =>
        findLinkedSigForSystem(parentSigs, sys);

      const getParentSigs = (pUuid: string): SystemSignature[] => {
        const pSys = findSystem(systems, pUuid);
        const pSolarId = getSystemSolarIdStr(pSys);
        return [...(systemSignatures[pUuid] || []), ...(pSolarId ? systemSignatures[pSolarId] || [] : [])];
      };

      const incoming = connections.filter(
        c =>
          (c.target === targetUuid || (!!sysSolarId && c.target === sysSolarId)) &&
          (c.type === undefined || c.type === 0),
      );

      let primaryLinkedSig: SystemSignature | undefined;
      for (const conn of incoming) {
        const candidateSig = findLinkedSig(getParentSigs(conn.source));
        if (candidateSig) {
          primaryLinkedSig = candidateSig;
          break;
        }
      }

      // A. Check if the system has its own custom label, tag, or temporary_name
      const ownLabel = ignoreManualLabels ? null : getOwnValidLabel(sys, primaryLinkedSig);
      if (ownLabel) {
        for (const conn of incoming) {
          const linkedSig = findLinkedSig(getParentSigs(conn.source));
          if (linkedSig) {
            const sInfo = parseSignatureCustomInfo(linkedSig.custom_info);
            const allowSingleHopAuto =
              hasSingleHopAutoMode ||
              !sInfo.bookmark_index_chained ||
              (typeof sInfo.bookmark_index === 'number' &&
                sInfo.bookmark_index_chained === String(sInfo.bookmark_index));
            const matchesAutoSigLabel =
              ownLabel === sInfo.bookmark_index_chained ||
              ownLabel === sInfo.bookmark_index_chained_letters ||
              (allowSingleHopAuto &&
                typeof sInfo.bookmark_index === 'number' &&
                (ownLabel === String(sInfo.bookmark_index) ||
                  ownLabel === numberToLetters(sInfo.bookmark_index, startAtZero)));

            if (matchesAutoSigLabel) {
              if (typeof sInfo.bookmark_index === 'number') {
                const branchVisited = new Set(visited);
                const liveParent = getSystemChainIndex(conn.source, branchVisited);
                if (!liveParent?.isCycle && liveParent && liveParent.indexStr !== '') {
                  return {
                    indexStr: `${liveParent.indexStr}${separator}${sInfo.bookmark_index}`,
                    lettersStr: `${liveParent.lettersStr}${separator}${sInfo.bookmark_index}`,
                  };
                }
              }
              if (
                sInfo.bookmark_index_chained === ownLabel &&
                typeof sInfo.bookmark_index_chained_letters === 'string' &&
                sInfo.bookmark_index_chained_letters !== ''
              ) {
                return { indexStr: ownLabel, lettersStr: sInfo.bookmark_index_chained_letters };
              }
              if (
                sInfo.bookmark_index_chained_letters === ownLabel &&
                typeof sInfo.bookmark_index_chained === 'string' &&
                sInfo.bookmark_index_chained !== ''
              ) {
                return { indexStr: sInfo.bookmark_index_chained, lettersStr: ownLabel };
              }
              if (
                typeof sInfo.bookmark_index === 'number' &&
                typeof sInfo.bookmark_index_chained === 'string' &&
                sInfo.bookmark_index_chained !== ''
              ) {
                return {
                  indexStr: sInfo.bookmark_index_chained,
                  lettersStr:
                    typeof sInfo.bookmark_index_chained_letters === 'string' &&
                    sInfo.bookmark_index_chained_letters !== ''
                      ? sInfo.bookmark_index_chained_letters
                      : ownLabel,
                };
              }
            }
          }
        }

        const autoModes = [
          settings?.system_auto_tag,
          settings?.system_custom_label_name,
          settings?.bookmark_auto_temp_name,
        ];
        const isSingleHopAutoSetting =
          autoModes.some(m => m === 'index' || m === 'index_letter') &&
          !autoModes.some(m => m === 'chain_index' || m === 'chain_index_letters');

        if (isSingleHopAutoSetting && incoming.length > 0 && /^(?:\d+|[A-Za-z])$/.test(ownLabel)) {
          for (const conn of incoming) {
            const branchVisited = new Set(visited);
            const candidateParent = getSystemChainIndex(conn.source, branchVisited);
            if (!candidateParent?.isCycle && candidateParent && candidateParent.indexStr !== '') {
              const relIdx = /^\d+$/.test(ownLabel)
                ? ownLabel
                : String(ownLabel.toUpperCase().charCodeAt(0) - 65 + (startAtZero ? 0 : 1));
              return {
                indexStr: `${candidateParent.indexStr}${separator}${relIdx}`,
                lettersStr: `${candidateParent.lettersStr}${separator}${relIdx}`,
              };
            }
          }
        }

        const shouldPropagateParentPrefix = (
          ownPrefix: string,
          parentSourceId: string,
          candidateParent: { indexStr: string; lettersStr: string },
        ): boolean => {
          if (ownPrefix === candidateParent.indexStr || ownPrefix === candidateParent.lettersStr) {
            return true;
          }
          const structuralParent = getSystemChainIndex(parentSourceId, new Set(visited), true);
          if (
            structuralParent &&
            !structuralParent.isCycle &&
            structuralParent.indexStr !== '' &&
            (ownPrefix === structuralParent.indexStr ||
              ownPrefix === structuralParent.lettersStr ||
              candidateParent.indexStr !== structuralParent.indexStr ||
              candidateParent.lettersStr !== structuralParent.lettersStr)
          ) {
            return true;
          }
          return !structuralParent || structuralParent.indexStr === '';
        };

        if (!primaryLinkedSig && separator && incoming.length > 0) {
          const ownParts = ownLabel.split(separator);
          const lastPart = ownParts[ownParts.length - 1];
          const ownPrefix = ownParts.slice(0, -1).join(separator);
          if (ownParts.length >= 2 && /^\d+$/.test(lastPart)) {
            for (const conn of incoming) {
              const branchVisited = new Set(visited);
              const candidateParent = getSystemChainIndex(conn.source, branchVisited);
              if (!candidateParent?.isCycle && candidateParent && candidateParent.indexStr !== '') {
                const parentParts = candidateParent.indexStr.split(separator);
                if (
                  ownParts.length === parentParts.length + 1 &&
                  shouldPropagateParentPrefix(ownPrefix, conn.source, candidateParent)
                ) {
                  return {
                    indexStr: `${candidateParent.indexStr}${separator}${lastPart}`,
                    lettersStr: `${candidateParent.lettersStr}${separator}${lastPart}`,
                  };
                }
              }
            }
          }
        }

        if (!primaryLinkedSig && !separator && /^\d+$/.test(ownLabel) && ownLabel.length > 1) {
          for (const conn of incoming) {
            const branchVisited = new Set(visited);
            const candidateParent = getSystemChainIndex(conn.source, branchVisited);
            if (!candidateParent?.isCycle && candidateParent && candidateParent.indexStr !== '') {
              if (ownLabel.startsWith(candidateParent.indexStr) && ownLabel.length > candidateParent.indexStr.length) {
                return {
                  indexStr: ownLabel,
                  lettersStr: `${candidateParent.lettersStr}${ownLabel.slice(candidateParent.indexStr.length)}`,
                };
              }
              const ownPrefix = ownLabel.slice(0, -1);
              if (
                ownLabel.length === candidateParent.indexStr.length + 1 &&
                shouldPropagateParentPrefix(ownPrefix, conn.source, candidateParent)
              ) {
                const lastDigit = ownLabel.slice(-1);
                return {
                  indexStr: `${candidateParent.indexStr}${lastDigit}`,
                  lettersStr: `${candidateParent.lettersStr}${lastDigit}`,
                };
              }
            }
          }
        }
        if (!primaryLinkedSig && !separator && /^[A-Za-z]\d+$/.test(ownLabel)) {
          for (const conn of incoming) {
            const branchVisited = new Set(visited);
            const candidateParent = getSystemChainIndex(conn.source, branchVisited);
            if (!candidateParent?.isCycle && candidateParent && candidateParent.indexStr !== '') {
              const ownPrefix = ownLabel.slice(0, -1);
              if (
                ownLabel.length === candidateParent.lettersStr.length + 1 &&
                shouldPropagateParentPrefix(ownPrefix, conn.source, candidateParent)
              ) {
                const lastDigit = ownLabel.slice(-1);
                return {
                  indexStr: `${candidateParent.indexStr}${lastDigit}`,
                  lettersStr: `${candidateParent.lettersStr}${lastDigit}`,
                };
              }
            }
          }
        }
        return toChainPair(ownLabel);
      }

      if (sys.locked && !sys.linked_sig_eve_id) {
        return null;
      }

      // B. Check incoming connections to find parent
      if (incoming.length > 0) {
        // Prefer an incoming connection whose source system has the linked signature for this system,
        // and try non-cyclic incoming connections before falling back to a cycle.
        const sortedIncoming = [...incoming].sort((a, b) => {
          const aHasSig = findLinkedSig(getParentSigs(a.source)) !== undefined ? 0 : 1;
          const bHasSig = findLinkedSig(getParentSigs(b.source)) !== undefined ? 0 : 1;
          return aHasSig - bHasSig;
        });

        let selectedConn = sortedIncoming[0];
        let rawParentChain: { indexStr: string; lettersStr: string; isCycle?: boolean } | null = null;
        for (const conn of sortedIncoming) {
          const branchVisited = new Set(visited);
          const candidateChain = getSystemChainIndex(conn.source, branchVisited, ignoreManualLabels);
          if (!candidateChain?.isCycle) {
            selectedConn = conn;
            rawParentChain = candidateChain;
            break;
          }
          rawParentChain = candidateChain;
        }

        if (rawParentChain?.isCycle) {
          return rawParentChain;
        }
        const parentUuid = selectedConn.source;
        const parentChain = rawParentChain || { indexStr: '', lettersStr: '' };

        const parentSigs = getParentSigs(parentUuid);
        const linkedSig = findLinkedSig(parentSigs);
        const linkedSigIndex = linkedSig ? parseSignatureCustomInfo(linkedSig.custom_info).bookmark_index : undefined;

        let relativeIndex: number = startAtZero ? 0 : 1;
        if (typeof linkedSigIndex === 'number' && linkedSigIndex >= 0) {
          relativeIndex = linkedSigIndex;
        } else {
          // Find siblings of the targetUuid to assign a deterministic index while avoiding sibling tag collisions
          const parentSys = findSystem(systems, parentUuid);
          const parentSolarId = getSystemSolarIdStr(parentSys);
          const matchesParent = (id: string) =>
            id === parentUuid || (!!parentSys && id === parentSys.id) || (!!parentSolarId && id === parentSolarId);
          const matchesTarget = (id: string) =>
            id === targetUuid || id === sys.id || (!!sysSolarId && id === sysSolarId);

          const siblings = connections.filter(c => matchesParent(c.source) && (c.type === undefined || c.type === 0));
          siblings.sort((a, b) => a.target.localeCompare(b.target));

          const getSiblingTags = (sibTargetUuid: string): string[] => {
            const sibSys = findSystem(systems, sibTargetUuid);
            const tags: string[] = [];
            const sibSig = findLinkedSigForSystem(parentSigs, sibSys, sibTargetUuid);
            const own = sibSys ? getOwnValidLabel(sibSys, sibSig) : null;
            if (own) {
              tags.push(own);
              if (parentChain.indexStr !== '' && /^(?:\d+|[A-Za-z])$/.test(own)) {
                const relIdx = /^\d+$/.test(own)
                  ? own
                  : String(own.toUpperCase().charCodeAt(0) - 65 + (startAtZero ? 0 : 1));
                tags.push(`${parentChain.indexStr}${separator}${relIdx}`);
                tags.push(`${parentChain.lettersStr}${separator}${relIdx}`);
              }
            }
            if (sibSig) {
              const sInfo = parseSignatureCustomInfo(sibSig.custom_info);
              if (typeof sInfo.bookmark_index_chained === 'string' && sInfo.bookmark_index_chained !== '') {
                tags.push(sInfo.bookmark_index_chained);
              }
              if (
                typeof sInfo.bookmark_index_chained_letters === 'string' &&
                sInfo.bookmark_index_chained_letters !== ''
              ) {
                tags.push(sInfo.bookmark_index_chained_letters);
              }
            }
            return tags;
          };

          const siblingExistingTags = siblings
            .filter(c => !matchesTarget(c.target))
            .flatMap(c => getSiblingTags(c.target));

          const untaggedSiblings = siblings.filter(c => {
            if (matchesTarget(c.target)) return true;
            return getSiblingTags(c.target).length === 0;
          });

          const untaggedRank = Math.max(
            0,
            untaggedSiblings.findIndex(c => matchesTarget(c.target)),
          );

          let candidateIdx = startAtZero ? 0 : 1;
          let remaining = untaggedRank;
          let searchingSibling = true;
          while (searchingSibling) {
            const candChained =
              parentChain.indexStr !== '' ? `${parentChain.indexStr}${separator}${candidateIdx}` : `${candidateIdx}`;
            const candLetters =
              parentChain.lettersStr !== ''
                ? `${parentChain.lettersStr}${separator}${candidateIdx}`
                : numberToLetters(candidateIdx, startAtZero);

            if (!siblingExistingTags.includes(candChained) && !siblingExistingTags.includes(candLetters)) {
              if (remaining === 0) {
                relativeIndex = candidateIdx;
                searchingSibling = false;
              } else {
                remaining--;
                candidateIdx++;
              }
            } else {
              candidateIdx++;
            }
          }
        }

        const chained =
          parentChain.indexStr !== '' ? `${parentChain.indexStr}${separator}${relativeIndex}` : `${relativeIndex}`;
        const chainedLetters =
          parentChain.lettersStr !== ''
            ? `${parentChain.lettersStr}${separator}${relativeIndex}`
            : numberToLetters(relativeIndex, startAtZero);
        return { indexStr: chained, lettersStr: chainedLetters };
      }

      // C. Fallback: check if any signature in systemSignatures links to this system directly
      for (const [sigSysId, sigs] of Object.entries(systemSignatures)) {
        if (sigSysId === sys.id || (sysSolarId && sigSysId === sysSolarId)) continue;
        const linkedSig = findLinkedSig(sigs);
        if (linkedSig) {
          const sigInfo = parseSignatureCustomInfo(linkedSig.custom_info);
          const idx = sigInfo.bookmark_index!;
          const indexStr =
            sigInfo.bookmark_index_chained != null ? String(sigInfo.bookmark_index_chained) : String(idx);
          const lettersStr =
            sigInfo.bookmark_index_chained_letters != null
              ? String(sigInfo.bookmark_index_chained_letters)
              : numberToLetters(idx, startAtZero);
          return { indexStr, lettersStr };
        }
      }

      return null;
    };

    const currentChain = getSystemChainIndex(currentSystemUuid);
    if (currentChain && !currentChain.isCycle) {
      parentBookmarkIndex = currentChain.indexStr;
      parentBookmarkIndexLetters = currentChain.lettersStr;
    }
  }

  const currentSigsRaw = [
    ...(systemSignatures[currentSystemUuid] || []),
    ...(systemSignatures[currentSolarSystemId] || []),
  ];

  // Deduplicate in case both keys map to the same or overlapping arrays
  const uniqueCurrentSigs = Array.from(new Map(currentSigsRaw.map(sig => [sig.eve_id, sig])).values());

  const isSigManualReturnHole = (sig: SystemSignature) =>
    isReturnHoleSignature(parseSignatureCustomInfo(sig.custom_info), sig.temporary_name, returnHoleSymbol);

  const existingIndices = uniqueCurrentSigs
    .filter(
      sig =>
        sig.eve_id !== currentEveId &&
        sig.group === SignatureGroup.Wormhole &&
        !sig.deleted &&
        !isSigManualReturnHole(sig),
    )
    .map(sig => parseSignatureCustomInfo(sig.custom_info).bookmark_index)
    .filter((i): i is number => typeof i === 'number' && i >= 0);

  const signatureChainedTags = uniqueCurrentSigs
    .filter(
      sig =>
        sig.eve_id !== currentEveId &&
        sig.group === SignatureGroup.Wormhole &&
        !sig.deleted &&
        !isSigManualReturnHole(sig),
    )
    .map(sig => {
      const info = parseSignatureCustomInfo(sig.custom_info);
      return [info.bookmark_index_chained, info.bookmark_index_chained_letters];
    })
    .flat()
    .filter((t): t is string => typeof t === 'string' && t !== '');

  let i = startAtZero ? 0 : 1;
  const rawLocalSystems =
    systems && connections ? getLocalChainSystems(currentSystemUuid, systems, connections) : systems;

  const matchesCurrentSystem = (id: string) => id === currentSystemUuid || id === currentSolarSystemId;

  const directNeighborIds =
    connections && connections.length > 0
      ? new Set(
          connections
            .filter(
              c =>
                (matchesCurrentSystem(c.source) || matchesCurrentSystem(c.target)) &&
                (c.type === undefined || c.type === 0),
            )
            .map(c => (matchesCurrentSystem(c.source) ? c.target : c.source)),
        )
      : null;

  const outgoingNeighborIds =
    connections && connections.length > 0
      ? new Set(
          connections
            .filter(c => matchesCurrentSystem(c.source) && (c.type === undefined || c.type === 0))
            .map(c => c.target),
        )
      : null;

  // Filter out the target system itself so its own temporary automatic label does not pollute the collision check!
  const localSystems = rawLocalSystems.filter(
    s =>
      s.id !== currentSystemUuid &&
      s.id !== currentSolarSystemId &&
      getSystemSolarIdStr(s) !== currentSolarSystemId &&
      (currentEveId === '' || s.linked_sig_eve_id !== currentEveId) &&
      (!targetSystemUuid || (s.id !== targetSystemUuid && getSystemSolarIdStr(s) !== targetSystemUuid)),
  );

  const existingTags = [
    ...(localSystems || [])
      .map(s => {
        const sSolarId = getSystemSolarIdStr(s);
        const isDirectNeighbor =
          !directNeighborIds || directNeighborIds.has(s.id) || (!!sSolarId && directNeighborIds.has(sSolarId));
        const tag = s.tag?.trim();
        const customLabel = s.labels ? new LabelsManager(s.labels).customLabel?.trim() : '';
        const tempName = s.temporary_name?.trim();
        return [tag, customLabel, tempName].filter(val => {
          if (!val) return false;
          if (isDirectNeighbor) return true;
          return separator !== '' && val.includes(separator);
        });
      })
      .flat(),
    ...signatureChainedTags,
  ]
    .filter((t): t is string => typeof t === 'string' && t !== '')
    .map(t => t.toUpperCase());

  const outgoingSingleHopChildTags = (localSystems || [])
    .filter(s => {
      const sSolarId = getSystemSolarIdStr(s);
      return (
        !s.linked_sig_eve_id && (outgoingNeighborIds?.has(s.id) || (!!sSolarId && outgoingNeighborIds?.has(sSolarId)))
      );
    })
    .flatMap(s => {
      const tag = s.tag?.trim();
      const customLabel = s.labels ? new LabelsManager(s.labels).customLabel?.trim() : '';
      const tempName = s.temporary_name?.trim();
      return [tag, customLabel, tempName];
    })
    .filter((t): t is string => typeof t === 'string' && t !== '' && (separator === '' || !t.includes(separator)))
    .map(t => t.toUpperCase());

  if (parentBookmarkIndex !== undefined) {
    const parentTag = parentBookmarkIndex;
    let searching = true;
    while (searching) {
      const candidate = `${parentTag}${separator}${i}`;
      const candidateLetters =
        parentBookmarkIndexLetters !== undefined ? `${parentBookmarkIndexLetters}${separator}${i}` : candidate;
      const singleHopNum = `${i}`;
      const singleHopLetter = numberToLetters(i, startAtZero);
      if (
        existingTags.includes(candidate.toUpperCase()) ||
        existingTags.includes(candidateLetters.toUpperCase()) ||
        existingIndices.includes(i) ||
        outgoingSingleHopChildTags.includes(singleHopNum) ||
        outgoingSingleHopChildTags.includes(singleHopLetter.toUpperCase())
      ) {
        i++;
      } else {
        searching = false;
      }
    }
  } else {
    let searching = true;
    while (searching) {
      const candidateTag = numberToLetters(i, startAtZero);
      const candidateNum = `${i}`;
      if (
        existingTags.includes(candidateTag.toUpperCase()) ||
        existingTags.includes(candidateNum) ||
        existingIndices.includes(i)
      ) {
        i++;
      } else {
        searching = false;
      }
    }
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
  wormholesData: Record<string, Partial<WormholeDataRaw>> = {},
  startAtZero: boolean = false,
  mapping?: BookmarkCustomMapping,
  systemSignatures?: Record<string, SystemSignature[]>,
  currentSystemId?: string,
  currentSolarSystemId?: string,
  currentSystemStatics?: string[],
): string => {
  let result = formatStr;
  const info = parseSignatureCustomInfo(signature.custom_info);

  // Prepare {sig_letters} and {sig}
  const sigLetters = signature.eve_id.substring(0, 3).toUpperCase();
  const fullSig = signature.eve_id.toUpperCase();

  // Prepare {dest_type}
  const destTypeStr = resolveSignatureDestType(signature, destSystemClass, wormholesData);
  const finalDestTypeStr = formatDestString(destTypeStr, mapping);

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
      const sDestTypeStr = resolveSignatureDestType(sig, undefined, wormholesData);
      return formatDestString(sDestTypeStr, mapping);
    };

    const isSigReturnHole = (s: SystemSignature) => {
      if (s.eve_id === signature.eve_id && typeof bookmarkIndex === 'number') {
        return false;
      }
      const sInfo = parseSignatureCustomInfo(s.custom_info);
      return (
        (sInfo.bookmark_index === undefined &&
          (sInfo.bookmark_index_chained !== undefined || sInfo.bookmark_index_chained_letters !== undefined)) ||
        s.temporary_name?.trim() === '<'
      );
    };

    const sameClassSigs = isSigReturnHole(signature)
      ? []
      : sigsInSystem.filter(s => {
          if (s.group !== SignatureGroup.Wormhole || s.deleted || isSigReturnHole(s)) return false;
          return getSigDestClass(s) === finalDestTypeStr;
        });

    // Sort by eve_id to ensure consistent ordering across clients
    sameClassSigs.sort((a, b) => a.eve_id.localeCompare(b.eve_id));

    const indexInClass = sameClassSigs.findIndex(s => s.eve_id === signature.eve_id);
    if (indexInClass > 0 || (indexInClass === 0 && sameClassSigs.length > 1)) {
      destClassIndexStr = String.fromCharCode(97 + indexInClass); // 0->a, 1->b, 2->c...
    }
  }

  // Prepare {size} and {mass}
  let sizeStr = '';
  let massStr = '';
  let whDataForSize: Partial<WormholeDataRaw> | null = null;

  const isK162 = signature.type === 'K162';
  const k162DestType = info.k162Type || info.destType;

  if (signature.type && !isK162 && wormholesData[signature.type]) {
    whDataForSize = wormholesData[signature.type];
  } else if (isK162 && k162DestType) {
    const destOption = ALL_DEST_TYPES_MAP[k162DestType];
    if (destOption?.whClassName) {
      const whName = destOption.whClassName.split('_')[0];
      whDataForSize = wormholesData[whName];
    }
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
      const sizeMappingKeys: Record<ShipSizeStatus, BookmarkCustomMappingKey> = {
        [ShipSizeStatus.small]: 'size_small',
        [ShipSizeStatus.medium]: 'size_medium',
        [ShipSizeStatus.large]: 'size_large',
        [ShipSizeStatus.freight]: 'size_freight',
        [ShipSizeStatus.capital]: 'size_capital',
      };
      const mappingKey = sizeMappingKeys[sizeStatus];
      if (mapping && mapping[mappingKey] !== undefined) {
        sizeStr = mapping[mappingKey]!;
      } else {
        sizeStr = defaultSizeNames[sizeStatus] ?? SHIP_SIZES_NAMES_SHORT[sizeStatus] ?? '';
      }
    }
    if (whDataForSize.total_mass) {
      massStr = Number((whDataForSize.total_mass / 1_000_000_000).toFixed(2)).toString();
    }
  } else if (signature.type === 'K162') {
    if (mapping?.size_k162_unknown !== undefined) {
      sizeStr = mapping.size_k162_unknown;
    }
  }

  const indexStr = bookmarkIndex.toString();
  const indexLetterStr =
    typeof bookmarkIndex === 'number' ? numberToLetters(bookmarkIndex, startAtZero) : bookmarkIndex.toString();

  const tokenValues: Record<BookmarkFormatVariable, string> = {
    '{index}': indexStr,
    '{chain_index}': info.bookmark_index_chained || indexStr,
    '{index_letter}': indexLetterStr,
    '{chain_index_letters}': info.bookmark_index_chained_letters || info.bookmark_index_chained || indexLetterStr,
    '{sig_letters}': sigLetters,
    '{sig}': fullSig,
    '{dest_type}': finalDestTypeStr !== '?' ? finalDestTypeStr : '',
    '{dest_class_index}': destClassIndexStr,
    '{size}': sizeStr,
    '{mass}': massStr,
    '{type}': signature.type || '',
    '{time_status}': getTimeStatusString(info.time_status, mapping),
    '{mass_status}': getMassStatusString(info.mass_status, mapping),
    '{temporary_name}': signature.temporary_name || '',
    '{description}': signature.description || '',
    '{direction}': getDirectionString(signature.type, mapping),
    '{spawn_type}': getSpawnTypeString(signature.type, currentSystemStatics, mapping),
  };

  result = result.replace(
    /\{(?:index|chain_index|index_letter|chain_index_letters|sig_letters|sig|dest_type|dest_class_index|size|mass|type|time_status|mass_status|temporary_name|description|direction|spawn_type)\}/g,
    match => tokenValues[match as BookmarkFormatVariable] ?? '',
  );

  // Cleanup whitespace
  if (/^\s*$/.test(formatStr)) {
    return formatStr;
  }

  const leadingSpaces = formatStr.match(/^\s+/)?.[0] || '';
  const cleaned = result.trim().replace(/\s+/g, ' ');

  if (cleaned === '') {
    return leadingSpaces;
  }

  return `${leadingSpaces}${cleaned}`;
};

export const copyToClipboard = async (text: string) => {
  try {
    await navigator.clipboard.writeText(text);
  } catch (err) {
    console.warn('Failed to copy to clipboard', err);
  }
};

const formatAutoIndexValue = (
  mode: AutoFormatOption | null | undefined,
  idx: number | string | undefined,
  chainedStr?: string,
  chainedLettersStr?: string,
  startAtZero?: boolean,
): string | undefined => {
  if (!mode || idx === undefined) return undefined;
  const fallbackLetter = typeof idx === 'number' ? numberToLetters(idx, startAtZero) : idx.toString();
  switch (mode) {
    case 'index':
      return idx.toString();
    case 'index_letter':
      return fallbackLetter;
    case 'chain_index':
      return chainedStr || idx.toString();
    case 'chain_index_letters':
      return chainedLettersStr || chainedStr || fallbackLetter;
    default:
      return undefined;
  }
};

export const handleAutoBookmark = async (
  signature: SystemSignature,
  currentSettings: UserSettings | null | undefined,
  systemSignatures: Record<string, SystemSignature[]>,
  currentSystemId: string,
  currentSolarSystemId: string,
  wormholesData: Record<string, Partial<WormholeDataRaw>>,
  targetSystemClassGroup: string | null,
  targetSystemUuid?: string,
  targetSolarSystemId?: string,
  systems: SolarSystemRawType[] = [],
  rawConnections: SolarSystemConnection[] = [],
): Promise<{ updatedSignature: SystemSignature; shouldUpdate: boolean }> => {
  const settings = currentSettings;
  let updatedSignature = signature;
  let shouldUpdate = false;

  const separator = settings?.bookmark_custom_mapping?.chain_separator || '';
  const returnHoleSymbol = getReturnHoleSymbol(settings);
  const connections = normalizeChainConnections(systems, rawConnections, systemSignatures, separator, returnHoleSymbol);

  const currentSystem = systems.find(s => s.id === currentSystemId);
  const currentSystemStatics =
    currentSystem?.system_static_info?.statics ||
    getSystemStaticInfo(currentSolarSystemId)?.statics ||
    getSystemStaticInfo(currentSystemId)?.statics;

  if (
    signature.group !== SignatureGroup.Wormhole ||
    (!settings?.bookmark_name_format &&
      !settings?.bookmark_auto_temp_name &&
      !settings?.system_auto_tag &&
      !settings?.system_custom_label_name)
  ) {
    return { updatedSignature, shouldUpdate };
  }

  const info = parseSignatureCustomInfo(signature.custom_info);
  let bookmarkIndex = info.bookmark_index;
  let bookmarkIndexToUse: number | string = bookmarkIndex != null ? bookmarkIndex : '';

  const wasMarkedReturnHole = isReturnHoleSignature(info, undefined, undefined);
  const previousAutoTempNames = new Set(
    (wasMarkedReturnHole
      ? [info.bookmark_index_chained, info.bookmark_index_chained_letters]
      : [settings?.bookmark_auto_temp_name, settings?.system_custom_label_name, settings?.system_auto_tag].map(mode =>
          formatAutoIndexValue(
            mode,
            info.bookmark_index,
            info.bookmark_index_chained,
            info.bookmark_index_chained_letters,
            settings?.bookmark_wormholes_start_at_zero,
          ),
        )
    ).filter((v): v is string => typeof v === 'string' && v !== ''),
  );
  const wasAutoTempName = !!signature.temporary_name && previousAutoTempNames.has(signature.temporary_name);

  let isReturnHole = false;
  let symbol = '';

  const targetSystem = systems.find(
    s =>
      (!!targetSystemUuid && s.id === targetSystemUuid) ||
      (!!targetSolarSystemId && (s.id === targetSolarSystemId || getSystemSolarIdStr(s) === targetSolarSystemId)),
  );
  const isTargetLinkedToCurrentSig =
    !!targetSystem?.linked_sig_eve_id && targetSystem.linked_sig_eve_id === signature.eve_id;

  if (
    settings?.bookmark_return_hole_ignore &&
    !isTargetLinkedToCurrentSig &&
    (targetSystemUuid || targetSolarSystemId)
  ) {
    const targetSigsRaw = [
      ...(targetSystemUuid ? systemSignatures[targetSystemUuid] || [] : []),
      ...(targetSolarSystemId ? systemSignatures[targetSolarSystemId] || [] : []),
    ];

    const uniqueTargetSigs = Array.from(new Map(targetSigsRaw.map(sig => [sig.eve_id, sig])).values());

    isReturnHole = uniqueTargetSigs.some(sig => {
      if (sig.deleted) {
        return false;
      }

      if (sig.linked_system?.solar_system_id?.toString() !== currentSolarSystemId.toString()) {
        return false;
      }

      const sigInfo = parseSignatureCustomInfo(sig.custom_info);
      if (isReturnHoleSignature(sigInfo, sig.temporary_name, returnHoleSymbol)) {
        return false;
      }

      if (currentSystem?.linked_sig_eve_id && sig.eve_id === currentSystem.linked_sig_eve_id) {
        return true;
      }

      if (sig.inserted_at && signature.inserted_at) {
        const sigTime = new Date(sig.inserted_at).getTime();
        const currentSigTime = new Date(signature.inserted_at).getTime();
        if (sigTime !== currentSigTime) {
          return sigTime < currentSigTime;
        }
      }

      if (sig.inserted_at && !signature.inserted_at) {
        return true;
      }

      if (!sig.inserted_at && signature.inserted_at) {
        return false;
      }

      return info.bookmark_index == null;
    });

    if (!isReturnHole) {
      const hasReturnHoleInTarget = uniqueTargetSigs.some(sig => {
        if (sig.deleted || sig.linked_system?.solar_system_id?.toString() !== currentSolarSystemId.toString()) {
          return false;
        }
        const sigInfo = parseSignatureCustomInfo(sig.custom_info);
        return isReturnHoleSignature(sigInfo, sig.temporary_name, returnHoleSymbol);
      });

      const matchesTarget = (id: string) =>
        (!!targetSystemUuid && id === targetSystemUuid) ||
        (!!targetSolarSystemId && id === targetSolarSystemId.toString()) ||
        (!!targetSystem && (id === targetSystem.id || id === getSystemSolarIdStr(targetSystem)));

      const matchesCurrent = (id: string) =>
        (!!currentSystem && (id === currentSystem.id || id === getSystemSolarIdStr(currentSystem))) ||
        id === currentSolarSystemId.toString() ||
        id === currentSystemId.toString();

      const hasIncomingConnFromTarget = connections.some(
        c => (c.type === undefined || c.type === 0) && matchesTarget(c.source) && matchesCurrent(c.target),
      );
      const hasOutgoingConnToTarget = connections.some(
        c => (c.type === undefined || c.type === 0) && matchesCurrent(c.source) && matchesTarget(c.target),
      );

      if (hasIncomingConnFromTarget && !hasOutgoingConnToTarget && !hasReturnHoleInTarget) {
        isReturnHole = true;
      }
    }

    if (isReturnHole) {
      symbol = (settings.bookmark_return_hole_symbol || '').trim();
    }
  }

  if (
    !isReturnHole &&
    settings?.bookmark_return_hole_ignore &&
    !!returnHoleSymbol &&
    signature.temporary_name?.trim().toLowerCase() === returnHoleSymbol &&
    (!wasMarkedReturnHole || (!signature.linked_system?.solar_system_id && !targetSystemUuid && !targetSolarSystemId))
  ) {
    isReturnHole = true;
    symbol = (settings.bookmark_return_hole_symbol || '').trim();
  }

  const isAlreadyLinkedToSameTarget =
    info.bookmark_index !== undefined &&
    info.bookmark_index_chained !== undefined &&
    !!targetSolarSystemId &&
    signature.linked_system?.solar_system_id?.toString() === targetSolarSystemId.toString();

  if (isReturnHole) {
    if (info.bookmark_index !== undefined) {
      delete info.bookmark_index;
    }
    info.bookmark_index_chained = symbol;
    info.bookmark_index_chained_letters = symbol;
    bookmarkIndexToUse = symbol;
    updatedSignature = { ...signature, custom_info: JSON.stringify(info) };
    shouldUpdate = true;
  } else if (!isAlreadyLinkedToSameTarget) {
    const separator = settings?.bookmark_custom_mapping?.chain_separator || '';
    const calculated = calculateBookmarkIndex(
      systemSignatures,
      currentSystemId,
      currentSolarSystemId,
      signature.eve_id,
      settings?.bookmark_wormholes_start_at_zero,
      separator,
      systems,
      connections,
      currentSettings,
      targetSystemUuid,
    );
    bookmarkIndex = calculated.index;
    info.bookmark_index = calculated.index;
    info.bookmark_index_chained = calculated.chained;
    info.bookmark_index_chained_letters = calculated.chainedLetters;
    bookmarkIndexToUse = calculated.index;
    updatedSignature = { ...signature, custom_info: JSON.stringify(info) };
    shouldUpdate = true;
  } else if (typeof info.bookmark_index === 'number') {
    const separator = settings?.bookmark_custom_mapping?.chain_separator || '';
    const calculated = calculateBookmarkIndex(
      systemSignatures,
      currentSystemId,
      currentSolarSystemId,
      signature.eve_id,
      settings?.bookmark_wormholes_start_at_zero,
      separator,
      systems,
      connections,
      currentSettings,
      targetSystemUuid,
    );
    const calcIdxStr = String(calculated.index);
    const isRootLevel = calculated.chained === calcIdxStr;
    const newChained = isRootLevel
      ? String(info.bookmark_index)
      : `${calculated.chained.slice(0, calculated.chained.length - calcIdxStr.length)}${info.bookmark_index}`;
    const newChainedLetters = isRootLevel
      ? numberToLetters(info.bookmark_index, settings?.bookmark_wormholes_start_at_zero)
      : `${calculated.chainedLetters.slice(0, calculated.chainedLetters.length - calcIdxStr.length)}${info.bookmark_index}`;

    if (newChained !== info.bookmark_index_chained || newChainedLetters !== info.bookmark_index_chained_letters) {
      info.bookmark_index_chained = newChained;
      info.bookmark_index_chained_letters = newChainedLetters;
      updatedSignature = { ...signature, custom_info: JSON.stringify(info) };
      shouldUpdate = true;
    }
  }

  const needsTempNameUpdate =
    !updatedSignature.temporary_name ||
    wasAutoTempName ||
    (isReturnHole && updatedSignature.temporary_name !== symbol && settings?.bookmark_auto_temp_name);

  if (settings?.bookmark_auto_temp_name && needsTempNameUpdate) {
    const autoName =
      formatAutoIndexValue(
        settings.bookmark_auto_temp_name,
        bookmarkIndexToUse,
        info.bookmark_index_chained,
        info.bookmark_index_chained_letters,
        settings.bookmark_wormholes_start_at_zero,
      ) ?? '';
    if (autoName !== '' || isReturnHole) {
      updatedSignature = { ...updatedSignature, temporary_name: autoName };
      shouldUpdate = true;
    }
  } else if (wasAutoTempName && !settings?.bookmark_auto_temp_name) {
    const fallbackMode = settings?.system_custom_label_name || settings?.system_auto_tag;
    const syncedAutoName = isReturnHole
      ? ''
      : (formatAutoIndexValue(
          fallbackMode,
          bookmarkIndexToUse,
          info.bookmark_index_chained,
          info.bookmark_index_chained_letters,
          settings?.bookmark_wormholes_start_at_zero,
        ) ?? '');
    if (updatedSignature.temporary_name !== syncedAutoName) {
      updatedSignature = { ...updatedSignature, temporary_name: syncedAutoName };
      shouldUpdate = true;
    }
  } else if (wasMarkedReturnHole && !isReturnHole && wasAutoTempName) {
    updatedSignature = { ...updatedSignature, temporary_name: '' };
    shouldUpdate = true;
  }

  if (settings?.bookmark_name_format && settings?.bookmark_auto_copy !== false) {
    const formattedStr = formatBookmarkName(
      settings.bookmark_name_format,
      updatedSignature,
      targetSystemClassGroup,
      bookmarkIndexToUse,
      wormholesData,
      settings.bookmark_wormholes_start_at_zero,
      settings.bookmark_custom_mapping,
      systemSignatures,
      currentSystemId,
      currentSolarSystemId,
      currentSystemStatics,
    );

    // Run this synchronously to avoid clipboard issues if possible
    await copyToClipboard(formattedStr);
  }

  return { updatedSignature, shouldUpdate };
};

export const applySystemAutoTags = async (
  updatedSignature: SystemSignature,
  currentSettings: UserSettings | null | undefined,
  targetSystem: SolarSystemRawType | null | undefined,
  outCommand: OutCommandHandler,
): Promise<void> => {
  const settings = currentSettings;
  const systemAutoTag = settings?.system_auto_tag;
  const systemCustomLabelName = settings?.system_custom_label_name;

  if (!targetSystem || (!systemAutoTag && !systemCustomLabelName)) {
    return;
  }

  const info = parseSignatureCustomInfo(updatedSignature.custom_info);
  const tempName = updatedSignature.temporary_name?.trim();
  const returnHoleSymbol = getReturnHoleSymbol(settings);

  // Do not auto-tag the parent/target system when linking a return hole
  if (isReturnHoleSignature(info, tempName, returnHoleSymbol)) {
    return;
  }

  const autoGeneratedTempNames = new Set(
    [settings?.bookmark_auto_temp_name, settings?.system_custom_label_name, settings?.system_auto_tag]
      .map(mode =>
        formatAutoIndexValue(
          mode,
          info.bookmark_index,
          info.bookmark_index_chained,
          info.bookmark_index_chained_letters,
          settings?.bookmark_wormholes_start_at_zero,
        ),
      )
      .filter((v): v is string => typeof v === 'string' && v !== ''),
  );

  const hasCustomTempName = !!tempName && (info.bookmark_index === undefined || !autoGeneratedTempNames.has(tempName));

  const tagValue =
    hasCustomTempName && tempName
      ? tempName
      : info.bookmark_index !== undefined
        ? formatAutoIndexValue(
            systemAutoTag,
            info.bookmark_index,
            info.bookmark_index_chained,
            info.bookmark_index_chained_letters,
            settings?.bookmark_wormholes_start_at_zero,
          )
        : undefined;

  const labelValue =
    hasCustomTempName && tempName
      ? tempName
      : info.bookmark_index !== undefined
        ? formatAutoIndexValue(
            systemCustomLabelName,
            info.bookmark_index,
            info.bookmark_index_chained,
            info.bookmark_index_chained_letters,
            settings?.bookmark_wormholes_start_at_zero,
          )
        : undefined;

  if (systemAutoTag && tagValue) {
    await outCommand({
      type: OutCommand.updateSystemTag,
      data: {
        system_id: targetSystem.id,
        value: tagValue,
      },
    });
  }

  if (systemCustomLabelName && labelValue) {
    const outLabel = new LabelsManager(targetSystem.labels ?? '');
    outLabel.updateCustomLabel(labelValue);

    await outCommand({
      type: OutCommand.updateSystemLabels,
      data: {
        system_id: targetSystem.id,
        value: outLabel.toString(),
      },
    });
  }
};

const prepareCleanupPreviousLinkedSystem = (
  signatureData: SystemSignature,
  prevTargetSystem: SolarSystemRawType | undefined,
  currentSettings: UserSettings | null | undefined,
  systemSignatures: Record<string, SystemSignature[]>,
  systems: SolarSystemRawType[],
  outCommand: OutCommandHandler,
): { updatedSystems: SolarSystemRawType[]; flushCleanupCommands: () => Promise<void> } => {
  const noop = async () => {};
  if (!prevTargetSystem) return { updatedSystems: systems, flushCleanupCommands: noop };

  const returnHoleSymbol = getReturnHoleSymbol(currentSettings);
  const prevInfo = parseSignatureCustomInfo(signatureData.custom_info);
  if (isReturnHoleSignature(prevInfo, signatureData.temporary_name, returnHoleSymbol)) {
    return { updatedSystems: systems, flushCleanupCommands: noop };
  }

  let updatedPrevTarget = { ...prevTargetSystem };
  if (updatedPrevTarget.linked_sig_eve_id === signatureData.eve_id) {
    updatedPrevTarget.linked_sig_eve_id = null;
  }

  const hasOtherActiveSig = Object.values(systemSignatures)
    .flat()
    .some(s => {
      if (s.deleted || s.eve_id === signatureData.eve_id || s.group !== SignatureGroup.Wormhole) {
        return false;
      }
      const sInfo = parseSignatureCustomInfo(s.custom_info);
      if (isReturnHoleSignature(sInfo, s.temporary_name, returnHoleSymbol)) {
        return false;
      }
      const linkedId = s.linked_system?.solar_system_id?.toString();
      return !!linkedId && (linkedId === prevTargetSystem.id || linkedId === getSystemSolarIdStr(prevTargetSystem));
    });
  if (hasOtherActiveSig) {
    return {
      updatedSystems: systems.map(s => (s.id === prevTargetSystem.id ? updatedPrevTarget : s)),
      flushCleanupCommands: noop,
    };
  }

  const cleanupActions: Array<() => Promise<unknown>> = [];

  const prevAutoTag = formatAutoIndexValue(
    currentSettings?.system_auto_tag,
    prevInfo.bookmark_index,
    prevInfo.bookmark_index_chained,
    prevInfo.bookmark_index_chained_letters,
    currentSettings?.bookmark_wormholes_start_at_zero,
  );
  if (
    currentSettings?.system_auto_tag &&
    prevTargetSystem.tag &&
    (prevTargetSystem.tag === prevAutoTag || prevTargetSystem.tag === signatureData.temporary_name)
  ) {
    updatedPrevTarget = { ...updatedPrevTarget, tag: '' };
    cleanupActions.push(() =>
      outCommand({
        type: OutCommand.updateSystemTag,
        data: { system_id: prevTargetSystem.id, value: '' },
      }),
    );
  }

  const prevAutoLabel = formatAutoIndexValue(
    currentSettings?.system_custom_label_name,
    prevInfo.bookmark_index,
    prevInfo.bookmark_index_chained,
    prevInfo.bookmark_index_chained_letters,
    currentSettings?.bookmark_wormholes_start_at_zero,
  );
  const prevCustomLabel = prevTargetSystem.labels
    ? new LabelsManager(prevTargetSystem.labels).customLabel?.trim()
    : undefined;
  if (
    currentSettings?.system_custom_label_name &&
    prevCustomLabel &&
    (prevCustomLabel === prevAutoLabel || prevCustomLabel === signatureData.temporary_name)
  ) {
    const outLabel = new LabelsManager(prevTargetSystem.labels ?? '');
    outLabel.updateCustomLabel('');
    const newLabelsStr = outLabel.toString();
    updatedPrevTarget = { ...updatedPrevTarget, labels: newLabelsStr };
    cleanupActions.push(() =>
      outCommand({
        type: OutCommand.updateSystemLabels,
        data: { system_id: prevTargetSystem.id, value: newLabelsStr },
      }),
    );
  }

  if (
    prevTargetSystem.temporary_name &&
    (prevTargetSystem.temporary_name === signatureData.temporary_name ||
      prevTargetSystem.temporary_name === prevAutoTag ||
      prevTargetSystem.temporary_name === prevAutoLabel)
  ) {
    updatedPrevTarget = { ...updatedPrevTarget, temporary_name: '' };
    cleanupActions.push(() =>
      outCommand({
        type: OutCommand.updateSystemTemporaryName,
        data: { system_id: prevTargetSystem.id, value: '' },
      }),
    );
  }

  return {
    updatedSystems: systems.map(s => (s.id === prevTargetSystem.id ? updatedPrevTarget : s)),
    flushCleanupCommands: async () => {
      for (const action of cleanupActions) {
        await action();
      }
    },
  };
};

export interface ExecuteLinkSignatureParams {
  signature: SystemSignature;
  data: CommandLinkSignatureToSystem;
  targetSystemClassGroup: string | null;
  userSettings: UserSettings | null;
  systemSignatures: Record<string, SystemSignature[]>;
  systems: SolarSystemRawType[];
  wormholesData: Record<string, Partial<WormholeDataRaw>>;
  connections: SolarSystemConnection[];
  outCommand: OutCommandHandler;
}

export const executeLinkSignatureToSystem = async ({
  signature,
  data,
  targetSystemClassGroup,
  userSettings,
  systemSignatures,
  systems,
  wormholesData,
  connections,
  outCommand,
}: ExecuteLinkSignatureParams) => {
  const sourceSolarStr = data.solar_system_source?.toString();
  const sourceSystem = findSystem(systems, sourceSolarStr);
  const systemUuid = sourceSystem?.id || sourceSolarStr;

  const targetSolarSystemIdStr = data.solar_system_target?.toString();
  const targetSystem = findSystem(systems, targetSolarSystemIdStr);
  const targetSystemUuid = targetSystem?.id;

  const signatureToLink = { ...signature, group: SignatureGroup.Wormhole };

  const currentSettings = await ensureUserSettings(userSettings, outCommand);

  const prevLinkedSolarId = signature.linked_system?.solar_system_id?.toString();
  let effectiveSystems = systems;
  let flushPrevCleanup: (() => Promise<void>) | undefined;
  if (prevLinkedSolarId && prevLinkedSolarId !== targetSolarSystemIdStr) {
    const prevTargetSystem = findSystem(systems, prevLinkedSolarId);
    const cleanup = prepareCleanupPreviousLinkedSystem(
      signature,
      prevTargetSystem,
      currentSettings,
      systemSignatures,
      systems,
      outCommand,
    );
    effectiveSystems = cleanup.updatedSystems;
    flushPrevCleanup = cleanup.flushCleanupCommands;
  }

  const { updatedSignature, shouldUpdate } = await handleAutoBookmark(
    signatureToLink,
    currentSettings,
    systemSignatures,
    systemUuid,
    data.solar_system_source.toString(),
    wormholesData,
    targetSystemClassGroup,
    targetSystemUuid,
    targetSolarSystemIdStr,
    effectiveSystems,
    connections,
  );

  if (shouldUpdate) {
    await outCommand({
      type: OutCommand.updateSignatures,
      data: {
        system_id: `${data.solar_system_source}`,
        added: [],
        updated: [updatedSignature],
        removed: [],
        deleteTimeout: 0,
      },
    });
  }

  if (!hasDifferentActiveLinkedSig(targetSystem, signature.eve_id, systemSignatures)) {
    await applySystemAutoTags(updatedSignature, currentSettings, targetSystem, outCommand);
  }

  await outCommand({
    type: OutCommand.linkSignatureToSystem,
    data: {
      ...data,
      signature_eve_id: signature.eve_id,
    },
  });

  if (flushPrevCleanup) {
    await flushPrevCleanup();
  }

  return { updatedSignature, shouldUpdate };
};

export interface SignatureSettingsFormValues extends Omit<Partial<SystemSignature>, 'linked_system'> {
  linked_system?: string;
  destType?: string;
  k162Type?: string;
  time_status?: TimeStatus;
  mass_status?: MassState;
}

export interface ExecuteSaveSignatureSettingsParams {
  signatureData: SystemSignature;
  formValues: SignatureSettingsFormValues;
  systemId: string;
  userSettings: UserSettings | null;
  systemSignatures: Record<string, SystemSignature[]>;
  systems: SolarSystemRawType[];
  wormholesData: Record<string, Partial<WormholeDataRaw>>;
  connections: SolarSystemConnection[];
  outCommand: OutCommandHandler;
}

export const executeSaveSignatureSettings = async ({
  signatureData,
  formValues,
  systemId,
  userSettings,
  systemSignatures,
  systems,
  wormholesData,
  connections,
  outCommand,
}: ExecuteSaveSignatureSettingsParams) => {
  const { group, ...values } = formValues;
  let out = { ...signatureData };

  const currentSettings = await ensureUserSettings(userSettings, outCommand);

  switch (group) {
    case SignatureGroup.Wormhole: {
      const existingInfo = parseSignatureCustomInfo(signatureData.custom_info);
      const effectiveType = values.type ?? out.type;
      const validDestType =
        effectiveType &&
        MULTI_DEST_WHS.includes(effectiveType) &&
        values.destType &&
        DEST_TYPES_MAP_MAP[effectiveType]?.[values.destType]
          ? values.destType
          : undefined;
      out = {
        ...out,
        custom_info: JSON.stringify({
          ...existingInfo,
          destType: validDestType,
          k162Type: effectiveType === 'K162' ? values.k162Type : undefined,
          time_status: values.time_status,
          mass_status: values.mass_status,
        }),
      };

      if (values.type != null) {
        out = { ...out, type: values.type };
      }

      if (values.temporary_name != null) {
        out = { ...out, temporary_name: values.temporary_name };
      }

      if (signatureData.group !== SignatureGroup.Wormhole) {
        out = { ...out, name: '' };
      }

      break;
    }
    case SignatureGroup.CosmicSignature:
      out = { ...out, type: '', name: '' };
      break;
    default:
      if (values.name != null) {
        out = { ...out, name: values.name ?? '' };
      }
  }

  // If the signature was previously a Wormhole and the user changed it to another group (e.g. Relic/Data/Gas),
  // strip auto-generated wormhole bookmark metadata and temporary_name.
  if (signatureData.group === SignatureGroup.Wormhole && group !== SignatureGroup.Wormhole) {
    const prevInfo = parseSignatureCustomInfo(signatureData.custom_info);
    const hadWormholeMeta =
      prevInfo.bookmark_index !== undefined ||
      prevInfo.bookmark_index_chained !== undefined ||
      prevInfo.bookmark_index_chained_letters !== undefined ||
      prevInfo.destType !== undefined ||
      prevInfo.k162Type !== undefined;

    if (hadWormholeMeta) {
      const cleanedInfo = { ...prevInfo };
      delete cleanedInfo.bookmark_index;
      delete cleanedInfo.bookmark_index_chained;
      delete cleanedInfo.bookmark_index_chained_letters;
      delete cleanedInfo.destType;
      delete cleanedInfo.k162Type;
      out = { ...out, custom_info: JSON.stringify(cleanedInfo) };

      const prevTemp = signatureData.temporary_name?.trim();
      const autoCandidates = new Set(
        [
          prevInfo.bookmark_index_chained,
          prevInfo.bookmark_index_chained_letters,
          typeof prevInfo.bookmark_index === 'number' ? String(prevInfo.bookmark_index) : undefined,
          typeof prevInfo.bookmark_index === 'number'
            ? numberToLetters(prevInfo.bookmark_index, currentSettings?.bookmark_wormholes_start_at_zero)
            : undefined,
          currentSettings?.bookmark_return_hole_symbol?.trim(),
        ].filter((v): v is string => typeof v === 'string' && v !== ''),
      );
      if (prevTemp && autoCandidates.has(prevTemp) && (!values.temporary_name || values.temporary_name === prevTemp)) {
        out = { ...out, temporary_name: '' };
      }
    }
  }

  if (values.description != null) {
    out = { ...out, description: values.description };
  }

  const prevLinkedSolarId = signatureData.linked_system?.solar_system_id?.toString();
  const prevTargetSystem = prevLinkedSolarId ? findSystem(systems, prevLinkedSolarId) : undefined;

  // Note: when type of signature changed from WH to other type - we should drop name
  if (
    group !== SignatureGroup.Wormhole && // new
    signatureData.group === SignatureGroup.Wormhole && // prev
    signatureData.linked_system
  ) {
    out = { ...out, type: '' };
  }

  const shouldUnlinkPrevious =
    (group !== SignatureGroup.Wormhole &&
      signatureData.group === SignatureGroup.Wormhole &&
      signatureData.linked_system != null) ||
    (group === SignatureGroup.Wormhole &&
      signatureData.linked_system != null &&
      (!values.linked_system || values.linked_system.toString() !== prevLinkedSolarId));

  // Note: despite groups have optional type - this will always set
  out = { ...out, group: group! };

  let effectiveSystems = systems;
  if (shouldUnlinkPrevious) {
    const cleanup = prepareCleanupPreviousLinkedSystem(
      signatureData,
      prevTargetSystem,
      currentSettings,
      systemSignatures,
      systems,
      outCommand,
    );
    effectiveSystems = cleanup.updatedSystems;

    await outCommand({
      type: OutCommand.unlinkSignature,
      data: { signature_eve_id: signatureData.eve_id, solar_system_source: systemId },
    });

    await cleanup.flushCleanupCommands();
  }

  const userClearedTempName = Boolean(signatureData.temporary_name) && values.temporary_name === '';

  if (group === SignatureGroup.Wormhole) {
    const targetSystem = values.linked_system ? findSystem(effectiveSystems, values.linked_system) : undefined;

    let targetSystemClassGroup: string | null = null;
    const targetSystemStatic = targetSystem?.system_static_info || getSystemStaticInfo(values.linked_system);
    if (targetSystemStatic) {
      targetSystemClassGroup = getSystemClassGroup(targetSystemStatic.system_class);
    }

    const targetSystemUuid = targetSystem?.id;

    let targetSolarSystemIdStr = values.linked_system;
    if (targetSystemStatic?.solar_system_id) {
      targetSolarSystemIdStr = targetSystemStatic.solar_system_id.toString();
    }

    const currentSystem = findSystem(effectiveSystems, systemId);
    const currentSystemStatic = currentSystem?.system_static_info || getSystemStaticInfo(systemId);

    let solarSystemIdStr = systemId;
    if (currentSystemStatic?.solar_system_id) {
      solarSystemIdStr = currentSystemStatic.solar_system_id.toString();
    }

    const { updatedSignature } = await handleAutoBookmark(
      out,
      currentSettings,
      systemSignatures,
      currentSystem?.id || systemId,
      solarSystemIdStr,
      wormholesData,
      targetSystemClassGroup,
      targetSystemUuid,
      targetSolarSystemIdStr,
      effectiveSystems,
      connections,
    );
    out = userClearedTempName ? { ...updatedSignature, temporary_name: '' } : updatedSignature;
  }

  await outCommand({
    type: OutCommand.updateSignatures,
    data: {
      system_id: systemId,
      added: [],
      updated: [out],
      removed: [],
      deleteTimeout: 0,
    },
  });

  // Link after updateSignatures so the K162's linked_system_id is still nil
  // during signature update, preventing maybe_update_connection_* from
  // resetting connection properties set by the forward signature.
  if (group === SignatureGroup.Wormhole && values.linked_system) {
    const prevLinkedSolarSystemId = signatureData.linked_system?.solar_system_id?.toString();
    const isNewlyLinkedOrChanged = prevLinkedSolarSystemId !== values.linked_system.toString();
    const prevInfo = parseSignatureCustomInfo(signatureData.custom_info);
    const nextInfo = parseSignatureCustomInfo(out.custom_info);
    const sigBookmarkChanged =
      prevInfo.bookmark_index !== nextInfo.bookmark_index ||
      prevInfo.bookmark_index_chained !== nextInfo.bookmark_index_chained ||
      prevInfo.bookmark_index_chained_letters !== nextInfo.bookmark_index_chained_letters ||
      signatureData.temporary_name !== out.temporary_name;

    if ((isNewlyLinkedOrChanged || sigBookmarkChanged) && !userClearedTempName) {
      const targetSystem = findSystem(effectiveSystems, values.linked_system);
      if (!hasDifferentActiveLinkedSig(targetSystem, signatureData.eve_id, systemSignatures)) {
        await applySystemAutoTags(out, currentSettings, targetSystem, outCommand);
      }
    }

    await outCommand({
      type: OutCommand.linkSignatureToSystem,
      data: {
        signature_eve_id: signatureData.eve_id,
        solar_system_source: systemId,
        solar_system_target: values.linked_system,
      },
    });
  }

  return out;
};

export interface ExecuteManualConnectionAutoTagParams {
  source: string;
  target: string;
  addConnPromise: Promise<unknown>;
  outCommand: OutCommandHandler;
  getMapState: () => {
    systems: SolarSystemRawType[];
    connections: SolarSystemConnection[];
    systemSignatures: Record<string, SystemSignature[]>;
  };
}

export const executeManualConnectionAutoTag = async ({
  source,
  target,
  addConnPromise,
  outCommand,
  getMapState,
}: ExecuteManualConnectionAutoTagParams) => {
  try {
    const connRes = await addConnPromise;
    if (connRes && typeof connRes === 'object' && 'connection_type' in connRes && connRes.connection_type !== 0) {
      return;
    }
    const res = await outCommand<GetUserSettingsResponse>({ type: OutCommand.getUserSettings, data: null });
    const currentSettings = res?.user_settings;
    const { systems, connections, systemSignatures } = getMapState();

    if (currentSettings?.system_auto_tag || currentSettings?.system_custom_label_name) {
      let sourceSystem = findSystem(systems, source);
      let targetSystem = findSystem(systems, target);
      let effectiveSource = sourceSystem?.id || source;
      let effectiveTarget = targetSystem?.id || target;

      if (sourceSystem && targetSystem) {
        const sourceSolarId = getSystemSolarIdStr(sourceSystem);
        const targetSolarId = getSystemSolarIdStr(targetSystem);
        const matchesSource = (id: string) =>
          id === source || id === sourceSystem!.id || (!!sourceSolarId && id === sourceSolarId);
        const matchesTarget = (id: string) =>
          id === target || id === targetSystem!.id || (!!targetSolarId && id === targetSolarId);

        const existingConn = connections.find(
          c =>
            (matchesSource(c.source) && matchesTarget(c.target)) ||
            (matchesTarget(c.source) && matchesSource(c.target)),
        );
        if (existingConn && existingConn.type !== undefined && existingConn.type !== 0) {
          return;
        }

        const getSysSigs = (sys: SolarSystemRawType, idFallback: string) => {
          const solarId = getSystemSolarIdStr(sys);
          return [
            ...(systemSignatures[sys.id] || []),
            ...(idFallback !== sys.id ? systemSignatures[idFallback] || [] : []),
            ...(solarId && solarId !== sys.id && solarId !== idFallback ? systemSignatures[solarId] || [] : []),
          ];
        };

        const otherConns = connections.filter(c => c.id !== existingConn?.id && (c.type === undefined || c.type === 0));
        const sourceHasOtherConns = otherConns.some(c => matchesSource(c.source) || matchesSource(c.target));
        const targetHasOtherConns = otherConns.some(c => matchesTarget(c.source) || matchesTarget(c.target));
        const sourceHasSigs = getSysSigs(sourceSystem, source).some(s => !s.deleted);
        const targetHasSigs = getSysSigs(targetSystem, target).some(s => !s.deleted);
        const sourceHasAnyLabel =
          Boolean(sourceSystem.tag?.trim()) ||
          Boolean(sourceSystem.temporary_name?.trim()) ||
          Boolean(sourceSystem.labels && new LabelsManager(sourceSystem.labels).customLabel?.trim());
        const targetHasAnyLabel =
          Boolean(targetSystem.tag?.trim()) ||
          Boolean(targetSystem.temporary_name?.trim()) ||
          Boolean(targetSystem.labels && new LabelsManager(targetSystem.labels).customLabel?.trim());

        // If user dragged connection backwards from a brand-new isolated system (`source`) to an established/locked system (`target`),
        // treat `target` as the upstream parent and `source` as the new child!
        const isDraggedBackwardsToRoot =
          !sourceSystem.locked &&
          !sourceHasOtherConns &&
          !sourceHasAnyLabel &&
          ((!sourceHasSigs && targetHasSigs) || targetSystem.locked || targetHasOtherConns || targetHasAnyLabel);

        if (isDraggedBackwardsToRoot) {
          const tmpId = effectiveSource;
          effectiveSource = effectiveTarget;
          effectiveTarget = tmpId;
          const tmp = sourceSystem;
          sourceSystem = targetSystem;
          targetSystem = tmp;
        }

        const hasUnlinkedSourceWormholes = getSysSigs(sourceSystem, effectiveSource).some(
          s => s.group === SignatureGroup.Wormhole && !s.linked_system && !s.deleted,
        );
        if (currentSettings?.link_signature_on_splash && hasUnlinkedSourceWormholes) {
          return;
        }

        const hasTag = Boolean(targetSystem.tag && targetSystem.tag.trim() !== '');
        const hasLabel = Boolean(targetSystem.labels && new LabelsManager(targetSystem.labels).customLabel?.trim());
        const hasTempName = Boolean(targetSystem.temporary_name && targetSystem.temporary_name.trim() !== '');

        if (!hasTag && !hasLabel && !hasTempName && !targetSystem.locked) {
          const virtualConnection: SolarSystemConnection = {
            id: `${effectiveSource}_${effectiveTarget}`,
            source: effectiveSource,
            target: effectiveTarget,
            time_status: TimeStatus.reserved,
            mass_status: MassState.normal,
            ship_size_type: ShipSizeStatus.small,
            locked: false,
          };
          const normalizedConnections = connections
            .filter(
              c =>
                !(
                  (matchesSource(c.source) && matchesTarget(c.target)) ||
                  (matchesTarget(c.source) && matchesSource(c.target))
                ),
            )
            .concat(virtualConnection);

          const separator = currentSettings?.bookmark_custom_mapping?.chain_separator || '';
          const calculated = calculateBookmarkIndex(
            systemSignatures,
            effectiveSource,
            getSystemSolarIdStr(sourceSystem) || sourceSystem.id,
            '',
            currentSettings?.bookmark_wormholes_start_at_zero,
            separator,
            systems,
            normalizedConnections,
            currentSettings,
            effectiveTarget,
          );

          const mockSignature: SystemSignature = {
            eve_id: '',
            name: '',
            group: SignatureGroup.Wormhole,
            kind: SignatureKind.CosmicSignature,
            type: 'wh',
            custom_info: JSON.stringify({
              bookmark_index: calculated.index,
              bookmark_index_chained: calculated.chained,
              bookmark_index_chained_letters: calculated.chainedLetters,
            }),
          };

          await applySystemAutoTags(mockSignature, currentSettings, targetSystem, outCommand);
        }
      }
    }
  } catch (e) {
    console.warn('Failed to auto-tag manual connection', e);
  }
};
