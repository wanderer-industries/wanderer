import { CommentType, MapOptions, PingData, SystemSignature, UserPermissions } from '@/hooks/Mapper/types';
import { ActivitySummary, CharacterTypeRaw, TrackingCharacter } from '@/hooks/Mapper/types/character.ts';
import { SolarSystemConnection } from '@/hooks/Mapper/types/connection.ts';
import { DetailedKill, Kill } from '@/hooks/Mapper/types/kills.ts';
import { RoutesList } from '@/hooks/Mapper/types/routes.ts';
import { SolarSystemRawType, SolarSystemStaticInfoRaw } from '@/hooks/Mapper/types/system.ts';
import { WormholeDataRaw } from '@/hooks/Mapper/types/wormholes.ts';

export enum Commands {
  init = 'init',
  addSystems = 'add_systems',
  updateSystems = 'update_systems',
  systemCommentsUpdated = 'system_comments_updated',
  removeSystems = 'remove_systems',
  addConnections = 'add_connections',
  removeConnections = 'remove_connections',
  charactersUpdated = 'characters_updated',
  characterAdded = 'character_added',
  characterRemoved = 'character_removed',
  characterUpdated = 'character_updated',
  presentCharacters = 'present_characters',
  updateConnection = 'update_connection',
  mapUpdated = 'map_updated',
  killsUpdated = 'kills_updated',
  detailedKillsUpdated = 'detailed_kills_updated',
  routes = 'routes',
  userRoutes = 'user_routes',
  centerSystem = 'center_system',
  selectSystem = 'select_system',
  selectSystems = 'select_systems',
  linkSignatureToSystem = 'link_signature_to_system',
  signaturesUpdated = 'signatures_updated',
  systemCommentAdded = 'system_comment_added',
  systemCommentRemoved = 'system_comment_removed',
  characterActivityData = 'character_activity_data',
  trackingCharactersData = 'tracking_characters_data',
  updateActivity = 'update_activity',
  updateTracking = 'update_tracking',
  userSettingsUpdated = 'user_settings_updated',
  showTracking = 'show_tracking',
  pingAdded = 'ping_added',
  pingCancelled = 'ping_cancelled',
}

export type Command =
  | Commands.init
  | Commands.addSystems
  | Commands.updateSystems
  | Commands.removeSystems
  | Commands.removeConnections
  | Commands.addConnections
  | Commands.charactersUpdated
  | Commands.characterAdded
  | Commands.characterRemoved
  | Commands.characterUpdated
  | Commands.presentCharacters
  | Commands.updateConnection
  | Commands.mapUpdated
  | Commands.killsUpdated
  | Commands.detailedKillsUpdated
  | Commands.routes
  | Commands.userRoutes
  | Commands.selectSystem
  | Commands.selectSystems
  | Commands.centerSystem
  | Commands.linkSignatureToSystem
  | Commands.signaturesUpdated
  | Commands.systemCommentAdded
  | Commands.systemCommentRemoved
  | Commands.systemCommentsUpdated
  | Commands.characterActivityData
  | Commands.trackingCharactersData
  | Commands.userSettingsUpdated
  | Commands.updateActivity
  | Commands.updateTracking
  | Commands.showTracking
  | Commands.pingAdded
  | Commands.pingCancelled;

export type CommandInit = {
  systems: SolarSystemRawType[];
  system_signatures: Record<string, SystemSignature[]>;
  kills: Kill[];
  system_static_infos: SolarSystemStaticInfoRaw[];
  connections: SolarSystemConnection[];
  wormholes: WormholeDataRaw[];

  // TODO WHY HERE ANY?!!?!?
  effects: any[];
  characters: CharacterTypeRaw[];
  present_characters: string[];
  user_characters: string[];
  user_permissions: UserPermissions;
  hubs: string[];
  user_hubs: string[];
  routes: RoutesList;
  options: MapOptions;
  reset?: boolean;
  is_subscription_active?: boolean;
  main_character_eve_id?: string | null;
  following_character_eve_id?: string | null;
  map_slug?: string;
};

export type CommandAddSystems = SolarSystemRawType[];
export type CommandUpdateSystems = SolarSystemRawType[];
export type CommandRemoveSystems = number[];
export type CommandAddConnections = SolarSystemConnection[];
export type CommandRemoveConnections = string[];
export type CommandCharactersUpdated = CharacterTypeRaw[];
export type CommandCharacterAdded = CharacterTypeRaw;
export type CommandCharacterRemoved = CharacterTypeRaw;
export type CommandCharacterUpdated = CharacterTypeRaw;
export type CommandPresentCharacters = string[];
export type CommandUpdateConnection = SolarSystemConnection;
export type CommandSignaturesUpdated = string;
export type CommandMapUpdated = Partial<CommandInit>;
export type CommandRoutes = RoutesList;
export type CommandUserRoutes = RoutesList;
export type CommandKillsUpdated = Kill[];
export type CommandDetailedKillsUpdated = Record<string, DetailedKill[]>;
export type CommandSelectSystem = string | undefined;
export type CommandSelectSystems = {
  systems: string[];
  delay?: number;
};
export type CommandCenterSystem = string | undefined;
export type CommandLinkSignatureToSystem = {
  solar_system_source: number;
  solar_system_target: number;
};
export type CommandLinkSignaturesUpdated = number;
export type CommandCommentAdd = {
  solarSystemId: string;
  comment: CommentType;
};
export type CommandCommentRemoved = {
  commentId: string;
  solarSystemId: number;
};
export type CommandCharacterActivityData = { activity: ActivitySummary[]; loading?: boolean };
export type CommandTrackingCharactersData = { characters: TrackingCharacter[] };
export type CommandUserSettingsUpdated = {
  settings: UserSettings;
};

export type CommandShowTracking = null;
export type CommandUpdateActivity = {
  characterId: number;
  systemId: number;
  shipTypeId: number;
  timestamp: number;
};
export type CommandUpdateTracking = {
  characterId: number;
  track: boolean;
  follow: boolean;
};
export type CommandPingAdded = PingData[];
export type CommandPingCancelled = Pick<PingData, 'type' | 'id'>;

export interface UserSettings {
  primaryCharacterId?: string;
  mapSettings?: {
    showGrid?: boolean;
    snapToGrid?: boolean;
    gridSize?: number;
  };
  interfaceSettings?: {
    theme?: string;
    showMinimap?: boolean;
    showMenu?: boolean;
  };
  [key: string]: unknown;
}

export interface CommandData {
  [Commands.init]: CommandInit;
  [Commands.addSystems]: CommandAddSystems;
  [Commands.updateSystems]: CommandUpdateSystems;
  [Commands.removeSystems]: CommandRemoveSystems;
  [Commands.addConnections]: CommandAddConnections;
  [Commands.removeConnections]: CommandRemoveConnections;
  [Commands.charactersUpdated]: CommandCharactersUpdated;
  [Commands.characterAdded]: CommandCharacterAdded;
  [Commands.characterRemoved]: CommandCharacterRemoved;
  [Commands.characterUpdated]: CommandCharacterUpdated;
  [Commands.presentCharacters]: CommandPresentCharacters;
  [Commands.updateConnection]: CommandUpdateConnection;
  [Commands.mapUpdated]: CommandMapUpdated;
  [Commands.routes]: CommandRoutes;
  [Commands.userRoutes]: CommandUserRoutes;
  [Commands.killsUpdated]: CommandKillsUpdated;
  [Commands.detailedKillsUpdated]: CommandDetailedKillsUpdated;
  [Commands.selectSystem]: CommandSelectSystem;
  [Commands.selectSystems]: CommandSelectSystems;
  [Commands.centerSystem]: CommandCenterSystem;
  [Commands.linkSignatureToSystem]: CommandLinkSignatureToSystem;
  [Commands.signaturesUpdated]: CommandLinkSignaturesUpdated;
  [Commands.characterActivityData]: CommandCharacterActivityData;
  [Commands.trackingCharactersData]: CommandTrackingCharactersData;
  [Commands.userSettingsUpdated]: CommandUserSettingsUpdated;
  [Commands.updateActivity]: CommandUpdateActivity;
  [Commands.updateTracking]: CommandUpdateTracking;
  [Commands.systemCommentAdded]: CommandCommentAdd;
  [Commands.systemCommentRemoved]: CommandCommentRemoved;
  [Commands.systemCommentsUpdated]: unknown;
  [Commands.showTracking]: CommandShowTracking;
  [Commands.pingAdded]: CommandPingAdded;
  [Commands.pingCancelled]: CommandPingCancelled;
}

export interface MapHandlers {
  command<T extends Command>(type: T, data: CommandData[T]): void;
}

export enum OutCommand {
  addHub = 'add_hub',
  deleteHub = 'delete_hub',
  addUserHub = 'add_user_hub',
  deleteUserHub = 'delete_user_hub',
  getRoutes = 'get_routes',
  getUserRoutes = 'get_user_routes',
  getCharacterJumps = 'get_character_jumps',
  getStructures = 'get_structures',
  getSignatures = 'get_signatures',
  getSystemStaticInfos = 'get_system_static_infos',
  getConnectionInfo = 'get_connection_info',
  loadSignatures = 'load_signatures',
  updateConnectionTimeStatus = 'update_connection_time_status',
  updateConnectionType = 'update_connection_type',
  updateConnectionMassStatus = 'update_connection_mass_status',
  updateConnectionShipSizeType = 'update_connection_ship_size_type',
  updateConnectionLocked = 'update_connection_locked',
  updateConnectionCustomInfo = 'update_connection_custom_info',
  updateStructures = 'update_structures',
  updateSignatures = 'update_signatures',
  updateSystemName = 'update_system_name',
  updateSystemTemporaryName = 'update_system_temporary_name',
  updateSystemDescription = 'update_system_description',
  updateSystemLabels = 'update_system_labels',
  updateSystemLocked = 'update_system_locked',
  updateSystemStatus = 'update_system_status',
  updateSystemTag = 'update_system_tag',
  updateSystemPosition = 'update_system_position',
  updateSystemPositions = 'update_system_positions',
  deleteSystems = 'delete_systems',
  manualAddSystem = 'manual_add_system',
  manualAddConnection = 'manual_add_connection',
  manualPasteSystemsAndConnections = 'manual_paste_systems_and_connections',
  manualDeleteConnection = 'manual_delete_connection',
  setAutopilotWaypoint = 'set_autopilot_waypoint',
  addSystem = 'add_system',
  openUserSettings = 'open_user_settings',
  getPassages = 'get_passages',
  linkSignatureToSystem = 'link_signature_to_system',
  getCorporationNames = 'get_corporation_names',
  getCorporationTicker = 'get_corporation_ticker',
  getSystemKills = 'get_system_kills',
  getSystemsKills = 'get_systems_kills',
  addSystemComment = 'addSystemComment',
  deleteSystemComment = 'deleteSystemComment',
  getSystemComments = 'getSystemComments',
  toggleFollow = 'toggle_follow',
  getCharacterInfo = 'getCharacterInfo',
  getCharactersTrackingInfo = 'getCharactersTrackingInfo',
  updateCharacterTracking = 'updateCharacterTracking',
  updateFollowingCharacter = 'updateFollowingCharacter',
  updateMainCharacter = 'updateMainCharacter',
  addPing = 'add_ping',
  cancelPing = 'cancel_ping',
  startTracking = 'startTracking',

  // Only UI commands
  openSettings = 'open_settings',
  showActivity = 'show_activity',
  showTracking = 'show_tracking',
  getUserSettings = 'get_user_settings',
  updateUserSettings = 'update_user_settings',
  saveDefaultSettings = 'save_default_settings',
  getDefaultSettings = 'get_default_settings',
  unlinkSignature = 'unlink_signature',
  searchSystems = 'search_systems',
  undoDeleteSignatures = 'undo_delete_signatures',
}

export type OutCommandHandler = <T = unknown>(event: { type: OutCommand; data: unknown }) => Promise<T>;
