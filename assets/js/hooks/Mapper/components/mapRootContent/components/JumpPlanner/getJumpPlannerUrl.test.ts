import type { JumpPlannerSettings } from '@/hooks/Mapper/mapRootProvider/types.ts';
import { getJumpPlannerUrl } from './getJumpPlannerUrl.ts';

const SETTINGS: JumpPlannerSettings = {
  shipType: 'Revelation Navy Issue',
  jumpDriveCalibration: 5,
  jumpFuelConservation: 4,
  jumpFreighter: 4,
  preferStationSystems: true,
  avoidIncursions: true,
};

describe('getJumpPlannerUrl', () => {
  it('normalizes spaces in DOTLAN ship and system path segments', () => {
    expect(getJumpPlannerUrl(SETTINGS, 'New Caldari', 'Old Man Star')).toBe(
      'https://evemaps.dotlan.net/jump/Revelation_Navy_Issue,544,S,I/New_Caldari:Old_Man_Star',
    );
  });

  it('omits optional route flags when they are disabled', () => {
    const settings = { ...SETTINGS, preferStationSystems: false, avoidIncursions: false };

    expect(getJumpPlannerUrl(settings, 'Jita', 'Amarr')).toBe(
      'https://evemaps.dotlan.net/jump/Revelation_Navy_Issue,544/Jita:Amarr',
    );
  });
});
