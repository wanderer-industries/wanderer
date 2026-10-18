import type { PageCharactersSettings } from './types';
import { PAGE_CHARACTERS_SETTINGS_VERSION } from './version';

export const DEFAULT_PAGE_CHARACTERS_SETTINGS: Readonly<PageCharactersSettings> = Object.freeze({
  version: PAGE_CHARACTERS_SETTINGS_VERSION,
  viewMode: 'cards',
  showBalances: false,
  promoHidden: false,
});

export const createDefaultPageCharactersSettings = (): PageCharactersSettings => {
  return { ...DEFAULT_PAGE_CHARACTERS_SETTINGS };
};

const isRecord = (value: unknown): value is Record<string, unknown> => {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
};

export const normalizePageCharactersSettings = (value: unknown): PageCharactersSettings => {
  const defaults = createDefaultPageCharactersSettings();
  if (!isRecord(value)) {
    return defaults;
  }

  const viewMode = value.viewMode;
  if (viewMode === 'cards' || viewMode === 'table' || viewMode === 'eve') {
    defaults.viewMode = viewMode;
  }

  if (typeof value.showBalances === 'boolean') {
    defaults.showBalances = value.showBalances;
  }

  if (typeof value.promoHidden === 'boolean') {
    defaults.promoHidden = value.promoHidden;
  }

  return defaults;
};
