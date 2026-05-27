import {
  SOLAR_SYSTEM_CLASS_IDS,
  SOLAR_SYSTEM_CLASSES_TO_CLASS_GROUPS,
} from '@/hooks/Mapper/components/map/constants.ts';

export const getSystemClassGroup = (systemClassId: number | undefined | null): string | null => {
  if (systemClassId == null) return null;

  const systemClassKey = Object.keys(SOLAR_SYSTEM_CLASS_IDS).find(
    key => SOLAR_SYSTEM_CLASS_IDS[key as keyof typeof SOLAR_SYSTEM_CLASS_IDS] === systemClassId,
  );

  if (!systemClassKey) return null;

  return (
    SOLAR_SYSTEM_CLASSES_TO_CLASS_GROUPS[systemClassKey as keyof typeof SOLAR_SYSTEM_CLASSES_TO_CLASS_GROUPS] || null
  );
};
