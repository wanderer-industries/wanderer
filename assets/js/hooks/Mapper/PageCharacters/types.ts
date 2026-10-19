import type { ForwardedRef, ReactNode } from 'react';

export type PageCharactersViewMode = 'cards' | 'table' | 'eve';
export type PageCharactersStatus = 'loading' | 'ready' | 'error';

export interface PageCharacterSystemInfo {
  solar_system_id: number;
  solar_system_name: string;
  region_name?: string;
  system_class: number;
  security: string;
  class_title: string;
}

export interface PageCharacter {
  id: string;
  eve_id: string;
  name: string;
  corporation_id: number;
  corporation_name: string | null;
  corporation_ticker: string | null;
  alliance_id: number | null;
  alliance_name: string | null;
  alliance_ticker: string | null;
  location_name: string | null;
  station_id: number | null;
  station_name: string | null;
  structure_id: number | null;
  system_info: PageCharacterSystemInfo | null;
  ship_name: string | null;
  ship_type_id: number | null;
  wallet_balance: number;
  show_wallet_balance: boolean;
  online: boolean;
  invalid_token: boolean;
}

export interface PageCharactersSnapshot {
  characters: PageCharacter[];
  wallet_tracking_enabled: boolean;
}

export interface PageCharactersCommandReply {
  ok: boolean;
  error?: string;
  snapshot?: PageCharactersSnapshot;
}

export type PageCharactersEventRef = string | number;

export enum PageCharactersCommand {
  snapshot = 'snapshot',
  characterUpdated = 'character_updated',
}

export interface PageCharactersCommandData {
  [PageCharactersCommand.snapshot]: PageCharactersSnapshot;
  [PageCharactersCommand.characterUpdated]: PageCharacter;
}

export type PageCharactersIncomingEvent =
  | { type: PageCharactersCommand.snapshot; body: PageCharactersSnapshot }
  | { type: PageCharactersCommand.characterUpdated; body: PageCharacter };

export interface PageCharactersHandlers {
  command<T extends PageCharactersCommand>(type: T, data: PageCharactersCommandData[T]): void;
}

export enum PageCharactersOutCommand {
  init = 'page_characters_init',
  authorize = 'page_characters_authorize',
  delete = 'page_characters_delete',
}

export type PageCharactersOutCommandEvent =
  | { type: PageCharactersOutCommand.init; data: Record<string, never> }
  | { type: PageCharactersOutCommand.authorize; data: { track_wallet: boolean } }
  | { type: PageCharactersOutCommand.delete; data: { character_id: string } };

export type PageCharactersOutCommandHandler = <T = unknown>(event: PageCharactersOutCommandEvent) => Promise<T>;

export interface PageCharactersHooks {
  handleEvent<T>(event: string, handler: (payload: T) => void): PageCharactersEventRef;
  removeHandleEvent(ref: PageCharactersEventRef): void;
  pushEventAsync<T>(event: string, payload: Record<string, unknown>): Promise<T>;
}

export interface PageCharactersProviderProps {
  fwdRef: ForwardedRef<PageCharactersHandlers>;
  outCommand: PageCharactersOutCommandHandler;
  children: ReactNode;
}

export interface PageCharactersContextValue {
  status: PageCharactersStatus;
  error: string | null;
  characters: PageCharacter[];
  filteredCharacters: PageCharacter[];
  walletTrackingEnabled: boolean;
  query: string;
  viewMode: PageCharactersViewMode;
  showBalances: boolean;
  promoHidden: boolean;
  deletingCharacterId: string | null;
  setQuery(query: string): void;
  setViewMode(mode: PageCharactersViewMode): void;
  setShowBalances(show: boolean): void;
  setPromoHidden(hidden: boolean): void;
  authorizeCharacter(trackWallet: boolean): Promise<void>;
  deleteCharacter(characterId: string): Promise<boolean>;
  refresh(): void;
}
