import { PingsPlacement } from '@/hooks/Mapper/mapRootProvider/types.ts';

export const SYSTEM_FOCUSED_LIFETIME = 10000;

export const GRADIENT_MENU_ACTIVE_CLASSES = 'bg-gradient-to-br from-transparent/10 to-fuchsia-300/10';

export enum Regions {
  Derelik = 10000001,
  TheForge = 10000002,
  Lonetrek = 10000016,
  SinqLaison = 10000032,
  Aridia = 10000054,
  BlackRise = 10000069,
  TheBleakLands = 10000038,
  TheCitadel = 10000033,
  Devoid = 10000036,
  Domain = 10000043,
  Essence = 10000064,
  Everyshore = 10000037,
  Genesis = 10000067,
  Heimatar = 10000030,
  Kador = 10000052,
  Khanid = 10000049,
  KorAzor = 10000065,
  Metropolis = 10000042,
  MoldenHeath = 10000028,
  Placid = 10000048,
  Solitude = 10000044,
  TashMurkon = 10000020,
  VergeVendor = 10000068,
  Pochven = 10000070,
}

export enum Spaces {
  'Caldari' = 'Caldari',
  'Gallente' = 'Gallente',
  'Matar' = 'Matar',
  'Amarr' = 'Amarr',
  'Pochven' = 'Pochven',
}

export const REGIONS_MAP: Record<number, Spaces> = {
  [Regions.Derelik]: Spaces.Amarr,
  [Regions.TheForge]: Spaces.Caldari,
  [Regions.Lonetrek]: Spaces.Caldari,
  [Regions.SinqLaison]: Spaces.Gallente,
  [Regions.Aridia]: Spaces.Amarr,
  [Regions.BlackRise]: Spaces.Caldari,
  [Regions.TheBleakLands]: Spaces.Amarr,
  [Regions.TheCitadel]: Spaces.Caldari,
  [Regions.Devoid]: Spaces.Amarr,
  [Regions.Domain]: Spaces.Amarr,
  [Regions.Essence]: Spaces.Gallente,
  [Regions.Everyshore]: Spaces.Gallente,
  [Regions.Genesis]: Spaces.Amarr,
  [Regions.Heimatar]: Spaces.Matar,
  [Regions.Kador]: Spaces.Amarr,
  [Regions.Khanid]: Spaces.Amarr,
  [Regions.KorAzor]: Spaces.Amarr,
  [Regions.Metropolis]: Spaces.Matar,
  [Regions.MoldenHeath]: Spaces.Matar,
  [Regions.Placid]: Spaces.Gallente,
  [Regions.Solitude]: Spaces.Gallente,
  [Regions.TashMurkon]: Spaces.Amarr,
  [Regions.VergeVendor]: Spaces.Gallente,
  [Regions.Pochven]: Spaces.Pochven,
};

export type K162Type = {
  label: string;
  value: string;
  whClassName: string;
};

export const K162_TYPES: K162Type[] = [
  {
    label: 'Hi-Sec',
    value: 'hs',
    whClassName: 'A641',
  },
  {
    label: 'Low-Sec',
    value: 'ls',
    whClassName: 'J377',
  },
  {
    label: 'Null-Sec',
    value: 'ns',
    whClassName: 'C248',
  },
  {
    label: 'C1',
    value: 'c1',
    whClassName: 'E004',
  },
  {
    label: 'C2',
    value: 'c2',
    whClassName: 'D382',
  },
  {
    label: 'C3',
    value: 'c3',
    whClassName: 'L477',
  },
  {
    label: 'C4',
    value: 'c4',
    whClassName: 'M001',
  },
  {
    label: 'C5',
    value: 'c5',
    whClassName: 'L614',
  },
  {
    label: 'C6',
    value: 'c6',
    whClassName: 'G008',
  },
  {
    label: 'C13',
    value: 'c13',
    whClassName: 'A009',
  },
  {
    label: 'Thera',
    value: 'thera',
    whClassName: 'F353',
  },
  {
    label: 'Pochven',
    value: 'pochven',
    whClassName: 'F216',
  },
];

export const K162_TYPES_MAP: { [key: string]: K162Type } = K162_TYPES.reduce(
  (acc, x) => ({ ...acc, [x.value]: x }),
  {},
);

export const MINIMAP_PLACEMENT_MAP = {
  [PingsPlacement.rightTop]: 'top-right',
  [PingsPlacement.leftTop]: 'top-left',
  [PingsPlacement.rightBottom]: 'bottom-right',
  [PingsPlacement.leftBottom]: 'bottom-left',
};

export const SPACE_TO_CLASS: Record<string, string> = {
  [Spaces.Caldari]: 'Caldaria',
  [Spaces.Matar]: 'Mataria',
  [Spaces.Amarr]: 'Amarria',
  [Spaces.Gallente]: 'Gallente',
  [Spaces.Pochven]: 'Pochven',
};
