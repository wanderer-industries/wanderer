import { LocationRaw } from '@/hooks/Mapper/types';

export const isDocked = (location: LocationRaw | null) => {
  if (!location) {
    return false;
  }

  return location.station_id != null || location.structure_id != null;
};
