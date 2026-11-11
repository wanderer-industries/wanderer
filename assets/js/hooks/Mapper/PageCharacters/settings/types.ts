import type { PageCharactersViewMode } from '../types';

export interface PageCharactersSettings {
  version: number;
  viewMode: PageCharactersViewMode;
  showBalances: boolean;
  promoHidden: boolean;
}

export type PageCharactersSettingsPatch = Partial<Omit<PageCharactersSettings, 'version'>>;

export interface PageCharactersSettingsMigration {
  to: number;
  up(previous: unknown): unknown;
}
