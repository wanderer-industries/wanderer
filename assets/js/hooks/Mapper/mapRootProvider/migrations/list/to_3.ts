import { MigrationStructure } from '@/hooks/Mapper/mapRootProvider/types.ts';
import { DEFAULT_ROUTES_BY_SETTINGS, DEFAULT_ROUTES_SETTINGS } from '@/hooks/Mapper/mapRootProvider/constants.ts';

export const to_3: MigrationStructure = {
  to: 3,
  up: (prev: any) => {
    const rawRoutesBy = prev?.routesBy;
    const hasStructuredRoutesBy =
      rawRoutesBy && typeof rawRoutesBy === 'object' && 'routes' in rawRoutesBy;

    const routes = hasStructuredRoutesBy
      ? { ...DEFAULT_ROUTES_SETTINGS, ...rawRoutesBy.routes }
      : { ...DEFAULT_ROUTES_SETTINGS, ...(rawRoutesBy ?? prev?.routes ?? {}) };

    const scopeRaw = hasStructuredRoutesBy ? rawRoutesBy?.scope : undefined;
    const scope = scopeRaw === 'HIGH' ? 'HIGH' : 'ALL';

    const type = hasStructuredRoutesBy && rawRoutesBy?.type ? rawRoutesBy.type : DEFAULT_ROUTES_BY_SETTINGS.type;

    return {
      ...prev,
      routesBy: {
        ...DEFAULT_ROUTES_BY_SETTINGS,
        ...(hasStructuredRoutesBy ? rawRoutesBy : {}),
        scope,
        type,
        routes,
      },
    };
  },
};
