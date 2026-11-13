import type { PageCharactersSettingsMigration } from '../../types';
import { to1 } from './to_1';

export const PAGE_CHARACTERS_SETTINGS_MIGRATIONS: ReadonlyArray<PageCharactersSettingsMigration> = [to1];
