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

export const SIGNATURE_WINDOW_ID = 'system_signatures_window';
export const SIGNATURE_SETTING_STORE_KEY = 'wanderer_system_signature_settings_v6_5';

export enum SETTINGS_KEYS {
  SHOW_DESCRIPTION_COLUMN = 'show_description_column',
  SHOW_UPDATED_COLUMN = 'show_updated_column',
  SHOW_CHARACTER_COLUMN = 'show_character_column',
  LAZY_DELETE_SIGNATURES = 'lazy_delete_signatures',
  KEEP_LAZY_DELETE = 'keep_lazy_delete_enabled',
  DELETION_TIMING = 'deletion_timing',
  COLOR_BY_TYPE = 'color_by_type',
  SHOW_CHARACTER_PORTRAIT = 'show_character_portrait',

  // From SignatureKind
  COSMIC_ANOMALY = SignatureKind.CosmicAnomaly,
  COSMIC_SIGNATURE = SignatureKind.CosmicSignature,
  DEPLOYABLE = SignatureKind.Deployable,
  STRUCTURE = SignatureKind.Structure,
  STARBASE = SignatureKind.Starbase,
  SHIP = SignatureKind.Ship,
  DRONE = SignatureKind.Drone,

  // From SignatureGroup
  WORMHOLE = SignatureGroup.Wormhole,
  RELIC_SITE = SignatureGroup.RelicSite,
  DATA_SITE = SignatureGroup.DataSite,
  ORE_SITE = SignatureGroup.OreSite,
  GAS_SITE = SignatureGroup.GasSite,
  COMBAT_SITE = SignatureGroup.CombatSite,
}

export enum SettingsTypes {
  flag,
  dropdown,
}

export type SignatureSettingsType = { [key in SETTINGS_KEYS]?: unknown };

export type Setting = {
  key: SETTINGS_KEYS;
  name: string;
  type: SettingsTypes;
  isSeparator?: boolean;
  options?: { label: string; value: number | string | boolean }[];
};

export enum SIGNATURES_DELETION_TIMING {
  IMMEDIATE,
  DEFAULT,
  EXTENDED,
}

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

export const SETTINGS_VALUES: SignatureSettingsType = {
  [SETTINGS_KEYS.SHOW_UPDATED_COLUMN]: true,
  [SETTINGS_KEYS.SHOW_DESCRIPTION_COLUMN]: true,
  [SETTINGS_KEYS.SHOW_CHARACTER_COLUMN]: true,
  [SETTINGS_KEYS.LAZY_DELETE_SIGNATURES]: true,
  [SETTINGS_KEYS.KEEP_LAZY_DELETE]: false,
  [SETTINGS_KEYS.DELETION_TIMING]: SIGNATURES_DELETION_TIMING.DEFAULT,
  [SETTINGS_KEYS.COLOR_BY_TYPE]: true,
  [SETTINGS_KEYS.SHOW_CHARACTER_PORTRAIT]: true,

  [SETTINGS_KEYS.COSMIC_ANOMALY]: true,
  [SETTINGS_KEYS.COSMIC_SIGNATURE]: true,
  [SETTINGS_KEYS.DEPLOYABLE]: true,
  [SETTINGS_KEYS.STRUCTURE]: true,
  [SETTINGS_KEYS.STARBASE]: true,
  [SETTINGS_KEYS.SHIP]: true,
  [SETTINGS_KEYS.DRONE]: true,

  [SETTINGS_KEYS.WORMHOLE]: true,
  [SETTINGS_KEYS.RELIC_SITE]: true,
  [SETTINGS_KEYS.DATA_SITE]: true,
  [SETTINGS_KEYS.ORE_SITE]: true,
  [SETTINGS_KEYS.GAS_SITE]: true,
  [SETTINGS_KEYS.COMBAT_SITE]: true,
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
