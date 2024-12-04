import { SolarSystemRawType, SolarSystemStaticInfoRaw } from '@/hooks/Mapper/types/system.ts';
import { SolarSystemConnection } from '@/hooks/Mapper/types/connection.ts';
import { WormholeDataRaw } from '@/hooks/Mapper/types/wormholes.ts';
import { CharacterTypeRaw } from '@/hooks/Mapper/types/character.ts';
import { RoutesList } from '@/hooks/Mapper/types/routes.ts';
import { Kill } from '@/hooks/Mapper/types/kills.ts';
import { UserPermissions } from '@/hooks/Mapper/types';

export enum Commands {
  init = 'init',
  addSystems = 'add_systems',
  updateSystems = 'update_systems',
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
  routes = 'routes',
  centerSystem = 'center_system',
  selectSystem = 'select_system',
  linkSignatureToSystem = 'link_signature_to_system',
  signaturesUpdated = 'signatures_updated',
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
  | Commands.routes
  | Commands.selectSystem
  | Commands.centerSystem
  | Commands.linkSignatureToSystem
  | Commands.signaturesUpdated;

export type CommandInit = {
  systems: SolarSystemRawType[];
  kills: Kill[];
  system_static_infos: SolarSystemStaticInfoRaw[];
  connections: SolarSystemConnection[];
  wormholes: WormholeDataRaw[];
  effects: any[];
  characters: CharacterTypeRaw[];
  present_characters: string[];
  user_characters: string[];
  user_permissions: UserPermissions;
  hubs: string[];
  routes: RoutesList;
  options: Record<string, string | boolean>;
  reset?: boolean;
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
export type CommandMapUpdated = Partial<CommandInit>;
export type CommandRoutes = RoutesList;
export type CommandKillsUpdated = Kill[];
export type CommandSelectSystem = string | undefined;
export type CommandCenterSystem = string | undefined;
export type CommandLinkSignatureToSystem = {
  solar_system_source: number;
  solar_system_target: number;
};
export type CommandLinkSignaturesUpdated = number;

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
  [Commands.killsUpdated]: CommandKillsUpdated;
  [Commands.selectSystem]: CommandSelectSystem;
  [Commands.centerSystem]: CommandCenterSystem;
  [Commands.linkSignatureToSystem]: CommandLinkSignatureToSystem;
  [Commands.signaturesUpdated]: CommandLinkSignaturesUpdated;
}

export interface MapHandlers {
  command<T extends Command>(type: T, data: CommandData[T]): void;
}

export enum OutCommand {
  addHub = 'add_hub',
  deleteHub = 'delete_hub',
  getRoutes = 'get_routes',
  getCharacterJumps = 'get_character_jumps',
  getSignatures = 'get_signatures',
  getSystemStaticInfos = 'get_system_static_infos',
  getConnectionInfo = 'get_connection_info',
  updateConnectionTimeStatus = 'update_connection_time_status',
  updateConnectionType = 'update_connection_type',
  updateConnectionMassStatus = 'update_connection_mass_status',
  updateConnectionShipSizeType = 'update_connection_ship_size_type',
  updateConnectionLocked = 'update_connection_locked',
  updateConnectionCustomInfo = 'update_connection_custom_info',
  updateSignatures = 'update_signatures',
  updateSystemName = 'update_system_name',
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
  manualDeleteConnection = 'manual_delete_connection',
  setAutopilotWaypoint = 'set_autopilot_waypoint',
  addSystem = 'add_system',
  addCharacter = 'add_character',
  openUserSettings = 'open_user_settings',
  getPassages = 'get_passages',
  linkSignatureToSystem = 'link_signature_to_system',

  // Only UI commands
  openSettings = 'open_settings',

  getUserSettings = 'get_user_settings',
  updateUserSettings = 'update_user_settings',
  unlinkSignature = 'unlink_signature',
}

export type OutCommandHandler = <T = any>(event: { type: OutCommand; data: any }) => Promise<T>;
