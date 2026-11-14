import { SOLAR_SYSTEM_CLASS_IDS } from '@/hooks/Mapper/components/map/constants.ts';

export const JUMP_PLANNER_FROM_SPACE = [
  SOLAR_SYSTEM_CLASS_IDS.hs,
  SOLAR_SYSTEM_CLASS_IDS.ls,
  SOLAR_SYSTEM_CLASS_IDS.ns,
];

export const JUMP_PLANNER_DESTINATION_SPACE = [SOLAR_SYSTEM_CLASS_IDS.ls, SOLAR_SYSTEM_CLASS_IDS.ns];

export enum JumpPlannerField {
  From = 'from',
  Destination = 'destination',
}

export const JUMP_SKILL_LEVEL_OPTIONS = [0, 1, 2, 3, 4, 5];

export const JUMP_SHIP_GROUPS = [
  {
    label: 'Black Ops',
    items: [
      { label: 'Marshal', value: 'Marshal' },
      { label: 'Panther', value: 'Panther' },
      { label: 'Python', value: 'Python' },
      { label: 'Redeemer', value: 'Redeemer' },
      { label: 'Sin', value: 'Sin' },
      { label: 'Widow', value: 'Widow' },
    ],
  },
  {
    label: 'Capital Industrial Ship',
    items: [{ label: 'Rorqual', value: 'Rorqual' }],
  },
  {
    label: 'Carrier',
    items: [
      { label: 'Archon', value: 'Archon' },
      { label: 'Chimera', value: 'Chimera' },
      { label: 'Nidhoggur', value: 'Nidhoggur' },
      { label: 'Thanatos', value: 'Thanatos' },
    ],
  },
  {
    label: 'Command Carrier',
    items: [
      { label: 'Gaia', value: 'Gaia' },
      { label: 'Salvation', value: 'Salvation' },
      { label: 'Simurgh', value: 'Simurgh' },
      { label: 'Ymir', value: 'Ymir' },
    ],
  },
  {
    label: 'Dreadnought',
    items: [
      { label: 'Caiman', value: 'Caiman' },
      { label: 'Chemosh', value: 'Chemosh' },
      { label: 'Moros', value: 'Moros' },
      { label: 'Moros Navy Issue', value: 'Moros Navy Issue' },
      { label: 'Naglfar', value: 'Naglfar' },
      { label: 'Naglfar Fleet Issue', value: 'Naglfar Fleet Issue' },
      { label: 'Phoenix', value: 'Phoenix' },
      { label: 'Phoenix Navy Issue', value: 'Phoenix Navy Issue' },
      { label: 'Revelation', value: 'Revelation' },
      { label: 'Revelation Navy Issue', value: 'Revelation Navy Issue' },
      { label: 'Sarathiel', value: 'Sarathiel' },
      { label: 'Vehement', value: 'Vehement' },
      { label: 'Zirnitra', value: 'Zirnitra' },
    ],
  },
  {
    label: 'Force Auxiliary',
    items: [
      { label: 'Apostle', value: 'Apostle' },
      { label: 'Dagon', value: 'Dagon' },
      { label: 'Lif', value: 'Lif' },
      { label: 'Loggerhead', value: 'Loggerhead' },
      { label: 'Minokawa', value: 'Minokawa' },
      { label: 'Ninazu', value: 'Ninazu' },
    ],
  },
  {
    label: 'Jump Freighter',
    items: [
      { label: 'Anshar', value: 'Anshar' },
      { label: 'Ark', value: 'Ark' },
      { label: 'Nomad', value: 'Nomad' },
      { label: 'Rhea', value: 'Rhea' },
    ],
  },
  {
    label: 'Jump Portal Array',
    items: [{ label: 'Jump Bridge', value: 'Jump Bridge' }],
  },
  {
    label: 'Lancer Dreadnought',
    items: [
      { label: 'Bane', value: 'Bane' },
      { label: 'Hubris', value: 'Hubris' },
      { label: 'Karura', value: 'Karura' },
      { label: 'Valravn', value: 'Valravn' },
    ],
  },
  {
    label: 'Supercarrier',
    items: [
      { label: 'Aeon', value: 'Aeon' },
      { label: 'Hel', value: 'Hel' },
      { label: 'Nyx', value: 'Nyx' },
      { label: 'Revenant', value: 'Revenant' },
      { label: 'Vendetta', value: 'Vendetta' },
      { label: 'Wyvern', value: 'Wyvern' },
    ],
  },
  {
    label: 'Titan',
    items: [
      { label: 'Avatar', value: 'Avatar' },
      { label: 'Azariel', value: 'Azariel' },
      { label: 'Erebus', value: 'Erebus' },
      { label: 'Komodo', value: 'Komodo' },
      { label: 'Leviathan', value: 'Leviathan' },
      { label: 'Molok', value: 'Molok' },
      { label: 'Ragnarok', value: 'Ragnarok' },
      { label: 'Vanquisher', value: 'Vanquisher' },
    ],
  },
];
