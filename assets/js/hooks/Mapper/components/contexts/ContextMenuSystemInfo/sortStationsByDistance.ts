import { RouteStationSummary } from '@/hooks/Mapper/types/routes.ts';

const ROMAN_VALUES: Record<string, number> = {
  I: 1,
  V: 5,
  X: 10,
  L: 50,
  C: 100,
  D: 500,
  M: 1000,
};

const MAX_DISTANCE = Number.MAX_SAFE_INTEGER;

const romanToInt = (value: string): number | null => {
  const chars = value.toUpperCase().split('');

  if (chars.length === 0 || chars.some(char => ROMAN_VALUES[char] === undefined)) {
    return null;
  }

  let total = 0;
  let prev = 0;

  for (let i = chars.length - 1; i >= 0; i--) {
    const current = ROMAN_VALUES[chars[i]];
    if (current < prev) {
      total -= current;
    } else {
      total += current;
      prev = current;
    }
  }

  return total;
};

const parseOrbitIndex = (value: string | undefined): number | null => {
  if (!value) {
    return null;
  }

  const trimmed = value.trim();
  const asInt = Number.parseInt(trimmed, 10);

  if (!Number.isNaN(asInt) && `${asInt}` === trimmed) {
    return asInt;
  }

  return romanToInt(trimmed);
};

const extractPlanetOrbit = (name: string): number | null => {
  const firstPart = name.split(' - ')[0] ?? '';
  const match = firstPart.match(/([IVXLCDM]+|\d+)(?:\s*\([^)]*\))?$/i);
  return parseOrbitIndex(match?.[1]);
};

const extractMoonOrbit = (name: string): number | null => {
  const match = name.match(/\bMoon\s+([IVXLCDM]+|\d+)\b/i);
  return parseOrbitIndex(match?.[1]);
};

const stationSortKey = (station: RouteStationSummary): [number, number, string, number] => {
  return [
    extractPlanetOrbit(station.station_name) ?? MAX_DISTANCE,
    // If there is no moon in the station name, treat it as closer than moon orbits.
    extractMoonOrbit(station.station_name) ?? 0,
    station.station_name.toLowerCase(),
    station.station_id,
  ];
};

export const sortStationsByDistance = (stations: RouteStationSummary[]): RouteStationSummary[] => {
  return [...stations].sort((a, b) => {
    const aKey = stationSortKey(a);
    const bKey = stationSortKey(b);

    for (let i = 0; i < aKey.length; i++) {
      if (aKey[i] < bKey[i]) {
        return -1;
      }
      if (aKey[i] > bKey[i]) {
        return 1;
      }
    }

    return 0;
  });
};
