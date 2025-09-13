import { SignatureGroup, SignatureKind } from '@/hooks/Mapper/types';

export const SIGNATURE_WINDOW_ID = 'system_signatures_window';

export enum SIGNATURES_DELETION_TIMING {
  IMMEDIATE,
  DEFAULT,
  EXTENDED,
}

export enum SETTINGS_KEYS {
  SORT_FIELD = 'sortField',
  SORT_ORDER = 'sortOrder',

  SHOW_ADDED_COLUMN = 'show_added_column',
  SHOW_CHARACTER_COLUMN = 'show_character_column',
  SHOW_CHARACTER_PORTRAIT = 'show_character_portrait',
  SHOW_DESCRIPTION_COLUMN = 'show_description_column',
  SHOW_GROUP_COLUMN = 'show_group_column',
  SHOW_UPDATED_COLUMN = 'show_updated_column',
  LAZY_DELETE_SIGNATURES = 'lazy_delete_signatures',
  KEEP_LAZY_DELETE = 'keep_lazy_delete_enabled',
  DELETION_TIMING = 'deletion_timing',
  COLOR_BY_TYPE = 'color_by_type',

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

export type SignatureSettingsType = { [key in SETTINGS_KEYS]?: unknown };

export const DEFAULT_SIGNATURE_SETTINGS: SignatureSettingsType = {
  [SETTINGS_KEYS.SORT_FIELD]: 'inserted_at',
  [SETTINGS_KEYS.SORT_ORDER]: -1,

  [SETTINGS_KEYS.SHOW_GROUP_COLUMN]: true,
  [SETTINGS_KEYS.SHOW_ADDED_COLUMN]: true,
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
