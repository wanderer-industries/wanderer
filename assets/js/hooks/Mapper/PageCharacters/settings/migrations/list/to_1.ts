import { normalizePageCharactersSettings } from '../../defaults';
import type { PageCharactersSettingsMigration } from '../../types';

export const to1: PageCharactersSettingsMigration = {
  to: 1,
  up: previous => normalizePageCharactersSettings(previous),
};
