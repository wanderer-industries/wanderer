import { SETTINGS_KEYS, SIGNATURES_DELETION_TIMING, SignatureSettingsType } from '@/hooks/Mapper/constants/signatures';
import {
  GroupType,
  SignatureGroup,
  SignatureGroupDE,
  SignatureGroupENG,
  SignatureGroupFR,
  SignatureGroupRU,
  SignatureKind,
  SignatureKindDE,
  SignatureKindENG,
  SignatureKindFR,
  SignatureKindRU,
} from '@/hooks/Mapper/types';

export const TIME_ONE_MINUTE = 1000 * 60;
export const TIME_TEN_MINUTES = TIME_ONE_MINUTE * 10;
export const TIME_ONE_DAY = 24 * 60 * TIME_ONE_MINUTE;
export const TIME_ONE_WEEK = 7 * TIME_ONE_DAY;
export const FINAL_DURATION_MS = 10000;

export const COMPACT_MAX_WIDTH = 260;
export const MEDIUM_MAX_WIDTH = 380;
export const OTHER_COLUMNS_WIDTH = 276;

export const GROUPS_LIST = [
  SignatureGroup.GasSite,
  SignatureGroup.RelicSite,
  SignatureGroup.DataSite,
  SignatureGroup.OreSite,
  SignatureGroup.CombatSite,
  SignatureGroup.Wormhole,
  SignatureGroup.CosmicSignature,
];

const wh = { w: 14, h: 14 };

export const GROUPS: Record<SignatureGroup, GroupType> = {
  [SignatureGroup.GasSite]: { id: SignatureGroup.GasSite, icon: '/icons/brackets/harvestableCloud.png', ...wh },
  [SignatureGroup.RelicSite]: { id: SignatureGroup.RelicSite, icon: '/icons/brackets/relic_Site_16.png', ...wh },
  [SignatureGroup.DataSite]: { id: SignatureGroup.DataSite, icon: '/icons/brackets/data_Site_16.png', ...wh },
  [SignatureGroup.OreSite]: { id: SignatureGroup.OreSite, icon: '/icons/brackets/ore_Site_16.png', ...wh },
  [SignatureGroup.CombatSite]: { id: SignatureGroup.CombatSite, icon: '/icons/brackets/combatSite_16.png', ...wh },
  [SignatureGroup.Wormhole]: { id: SignatureGroup.Wormhole, icon: '/icons/brackets/wormhole.png', ...wh },
  [SignatureGroup.CosmicSignature]: { id: SignatureGroup.CosmicSignature, icon: '/icons/x_close14.png', w: 9, h: 9 },
};

export const LANGUAGE_GROUP_MAPPINGS = {
  EN: {
    [SignatureGroupENG.GasSite]: SignatureGroup.GasSite,
    [SignatureGroupENG.RelicSite]: SignatureGroup.RelicSite,
    [SignatureGroupENG.DataSite]: SignatureGroup.DataSite,
    [SignatureGroupENG.OreSite]: SignatureGroup.OreSite,
    [SignatureGroupENG.CombatSite]: SignatureGroup.CombatSite,
    [SignatureGroupENG.Wormhole]: SignatureGroup.Wormhole,
    [SignatureGroupENG.CosmicSignature]: SignatureGroup.CosmicSignature,
  },
  RU: {
    [SignatureGroupRU.GasSite]: SignatureGroup.GasSite,
    [SignatureGroupRU.RelicSite]: SignatureGroup.RelicSite,
    [SignatureGroupRU.DataSite]: SignatureGroup.DataSite,
    [SignatureGroupRU.OreSite]: SignatureGroup.OreSite,
    [SignatureGroupRU.CombatSite]: SignatureGroup.CombatSite,
    [SignatureGroupRU.Wormhole]: SignatureGroup.Wormhole,
    [SignatureGroupRU.CosmicSignature]: SignatureGroup.CosmicSignature,
  },
  FR: {
    [SignatureGroupFR.GasSite]: SignatureGroup.GasSite,
    [SignatureGroupFR.RelicSite]: SignatureGroup.RelicSite,
    [SignatureGroupFR.DataSite]: SignatureGroup.DataSite,
    [SignatureGroupFR.OreSite]: SignatureGroup.OreSite,
    [SignatureGroupFR.CombatSite]: SignatureGroup.CombatSite,
    [SignatureGroupFR.Wormhole]: SignatureGroup.Wormhole,
    [SignatureGroupFR.CosmicSignature]: SignatureGroup.CosmicSignature,
  },
  DE: {
    [SignatureGroupDE.GasSite]: SignatureGroup.GasSite,
    [SignatureGroupDE.RelicSite]: SignatureGroup.RelicSite,
    [SignatureGroupDE.DataSite]: SignatureGroup.DataSite,
    [SignatureGroupDE.OreSite]: SignatureGroup.OreSite,
    [SignatureGroupDE.CombatSite]: SignatureGroup.CombatSite,
    [SignatureGroupDE.Wormhole]: SignatureGroup.Wormhole,
    [SignatureGroupDE.CosmicSignature]: SignatureGroup.CosmicSignature,
  },
};

// Flatten the structure for backward compatibility
export const MAPPING_GROUP_TO_ENG: Record<string, SignatureGroup> = (() => {
  const flattened: Record<string, SignatureGroup> = {};
  for (const [, mappings] of Object.entries(LANGUAGE_GROUP_MAPPINGS)) {
    Object.assign(flattened, mappings);
  }
  return flattened;
})();

export const getGroupIdByRawGroup = (val: string): SignatureGroup | undefined => {
  return MAPPING_GROUP_TO_ENG[val] || undefined;
};

export enum SettingsTypes {
  flag,
  dropdown,
}

export type Setting = {
  key: SETTINGS_KEYS;
  name: string;
  type: SettingsTypes;
  isSeparator?: boolean;
  options?: { label: string; value: number | string | boolean }[];
};

// Now use a stricter type: every timing key maps to a number
export type SignatureDeletionTimingType = Record<SIGNATURES_DELETION_TIMING, number>;

export const SIGNATURE_SETTINGS = {
  filterFlags: [
    { type: SettingsTypes.flag, key: SETTINGS_KEYS.COSMIC_ANOMALY, name: 'Show Anomalies' },
    { type: SettingsTypes.flag, key: SETTINGS_KEYS.COSMIC_SIGNATURE, name: 'Show Cosmic Signatures' },
    { type: SettingsTypes.flag, key: SETTINGS_KEYS.DEPLOYABLE, name: 'Show Deployables' },
    { type: SettingsTypes.flag, key: SETTINGS_KEYS.STRUCTURE, name: 'Show Structures' },
    { type: SettingsTypes.flag, key: SETTINGS_KEYS.STARBASE, name: 'Show Starbase' },
    { type: SettingsTypes.flag, key: SETTINGS_KEYS.SHIP, name: 'Show Ships' },
    { type: SettingsTypes.flag, key: SETTINGS_KEYS.DRONE, name: 'Show Drones And Charges' },
    { type: SettingsTypes.flag, key: SETTINGS_KEYS.WORMHOLE, name: 'Show Wormholes' },
    { type: SettingsTypes.flag, key: SETTINGS_KEYS.RELIC_SITE, name: 'Show Relic Sites' },
    { type: SettingsTypes.flag, key: SETTINGS_KEYS.DATA_SITE, name: 'Show Data Sites' },
    { type: SettingsTypes.flag, key: SETTINGS_KEYS.ORE_SITE, name: 'Show Ore Sites' },
    { type: SettingsTypes.flag, key: SETTINGS_KEYS.GAS_SITE, name: 'Show Gas Sites' },
    { type: SettingsTypes.flag, key: SETTINGS_KEYS.COMBAT_SITE, name: 'Show Combat Sites' },
  ],
  uiFlags: [
    { type: SettingsTypes.flag, key: SETTINGS_KEYS.SHOW_GROUP_COLUMN, name: 'Show Group Column' },
    { type: SettingsTypes.flag, key: SETTINGS_KEYS.SHOW_ADDED_COLUMN, name: 'Show Added Column' },
    { type: SettingsTypes.flag, key: SETTINGS_KEYS.SHOW_UPDATED_COLUMN, name: 'Show Updated Column' },
    { type: SettingsTypes.flag, key: SETTINGS_KEYS.SHOW_DESCRIPTION_COLUMN, name: 'Show Description Column' },
    { type: SettingsTypes.flag, key: SETTINGS_KEYS.SHOW_CHARACTER_COLUMN, name: 'Show Character Column' },
    { type: SettingsTypes.flag, key: SETTINGS_KEYS.LAZY_DELETE_SIGNATURES, name: 'Lazy Delete Signatures' },
    { type: SettingsTypes.flag, key: SETTINGS_KEYS.KEEP_LAZY_DELETE, name: 'Keep "Lazy Delete" Enabled' },
    {
      type: SettingsTypes.flag,
      key: SETTINGS_KEYS.SHOW_CHARACTER_PORTRAIT,
      name: 'Show Character Portrait in Tooltip',
    },
    { type: SettingsTypes.flag, key: SETTINGS_KEYS.COLOR_BY_TYPE, name: 'Color Signatures by Type' },
  ],
  uiOther: [
    {
      type: SettingsTypes.dropdown,
      key: SETTINGS_KEYS.DELETION_TIMING,
      name: 'Deletion Timing',
      options: [
        { value: SIGNATURES_DELETION_TIMING.IMMEDIATE, label: '0s' },
        { value: SIGNATURES_DELETION_TIMING.DEFAULT, label: '10s' },
        { value: SIGNATURES_DELETION_TIMING.EXTENDED, label: '30s' },
      ],
    },
  ],
};

// Now this map is strongly typed as “number” for each timing enum
export const SIGNATURE_DELETION_TIMEOUTS: SignatureDeletionTimingType = {
  [SIGNATURES_DELETION_TIMING.IMMEDIATE]: 0,
  [SIGNATURES_DELETION_TIMING.DEFAULT]: 10_000,
  [SIGNATURES_DELETION_TIMING.EXTENDED]: 30_000,
};

/**
 * Helper function to extract the deletion timeout in milliseconds from settings
 */
export function getDeletionTimeoutMs(settings: SignatureSettingsType): number {
  const raw = settings[SETTINGS_KEYS.DELETION_TIMING];
  const timing =
    raw && typeof raw === 'object' && 'value' in raw
      ? (raw as { value: SIGNATURES_DELETION_TIMING }).value
      : (raw as SIGNATURES_DELETION_TIMING | undefined);

  const validTiming = typeof timing === 'number' ? timing : SIGNATURES_DELETION_TIMING.DEFAULT;

  return SIGNATURE_DELETION_TIMEOUTS[validTiming];
}

// Replace the flat structure with a nested structure by language
export const LANGUAGE_TYPE_MAPPINGS = {
  EN: {
    [SignatureKindENG.CosmicSignature]: SignatureKind.CosmicSignature,
    [SignatureKindENG.CosmicAnomaly]: SignatureKind.CosmicAnomaly,
    [SignatureKindENG.Structure]: SignatureKind.Structure,
    [SignatureKindENG.Ship]: SignatureKind.Ship,
    [SignatureKindENG.Deployable]: SignatureKind.Deployable,
    [SignatureKindENG.Drone]: SignatureKind.Drone,
    [SignatureKindENG.Starbase]: SignatureKind.Starbase,
  },
  RU: {
    [SignatureKindRU.CosmicSignature]: SignatureKind.CosmicSignature,
    [SignatureKindRU.CosmicAnomaly]: SignatureKind.CosmicAnomaly,
    [SignatureKindRU.Structure]: SignatureKind.Structure,
    [SignatureKindRU.Ship]: SignatureKind.Ship,
    [SignatureKindRU.Deployable]: SignatureKind.Deployable,
    [SignatureKindRU.Drone]: SignatureKind.Drone,
    [SignatureKindRU.Starbase]: SignatureKind.Starbase,
  },
  FR: {
    [SignatureKindFR.CosmicSignature]: SignatureKind.CosmicSignature,
    [SignatureKindFR.CosmicAnomaly]: SignatureKind.CosmicAnomaly,
    [SignatureKindFR.Structure]: SignatureKind.Structure,
    [SignatureKindFR.Ship]: SignatureKind.Ship,
    [SignatureKindFR.Deployable]: SignatureKind.Deployable,
    [SignatureKindFR.Drone]: SignatureKind.Drone,
    [SignatureKindFR.Starbase]: SignatureKind.Starbase,
  },
  DE: {
    [SignatureKindDE.CosmicSignature]: SignatureKind.CosmicSignature,
    [SignatureKindDE.CosmicAnomaly]: SignatureKind.CosmicAnomaly,
    [SignatureKindDE.Structure]: SignatureKind.Structure,
    [SignatureKindDE.Ship]: SignatureKind.Ship,
    [SignatureKindDE.Deployable]: SignatureKind.Deployable,
    [SignatureKindDE.Drone]: SignatureKind.Drone,
    [SignatureKindDE.Starbase]: SignatureKind.Starbase,
  },
};

// Flatten the structure for backward compatibility
export const MAPPING_TYPE_TO_ENG: Record<string, SignatureKind> = (() => {
  const flattened: Record<string, SignatureKind> = {};
  for (const [, mappings] of Object.entries(LANGUAGE_TYPE_MAPPINGS)) {
    Object.assign(flattened, mappings);
  }
  return flattened;
})();
