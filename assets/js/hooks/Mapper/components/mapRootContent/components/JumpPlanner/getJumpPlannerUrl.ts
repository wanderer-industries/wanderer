import type { JumpPlannerSettings } from '@/hooks/Mapper/mapRootProvider/types.ts';

const normalizeDotlanPathSegment = (value: string) => encodeURIComponent(value.replaceAll(' ', '_'));

export const getJumpPlannerUrl = (settings: JumpPlannerSettings, from: string, destination: string) => {
  const { shipType, jumpDriveCalibration, jumpFuelConservation, jumpFreighter } = settings;
  const shipName = normalizeDotlanPathSegment(shipType);
  let ship = `${shipName},${jumpDriveCalibration}${jumpFuelConservation}${jumpFreighter}`;

  if (settings.preferStationSystems) {
    ship += ',S';
  }
  if (settings.avoidIncursions) {
    ship += ',I';
  }

  const route = `${normalizeDotlanPathSegment(from)}:${normalizeDotlanPathSegment(destination)}`;
  return `https://evemaps.dotlan.net/jump/${ship}/${route}`;
};
