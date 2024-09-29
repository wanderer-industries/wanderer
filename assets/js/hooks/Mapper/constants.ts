export enum SESSION_KEY {
  viewPort = 'viewPort',
  windows = 'windows',
  routes = 'routes',
}

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
}

export enum Spaces {
  'Caldari' = 'Caldari',
  'Gallente' = 'Gallente',
  'Matar' = 'Matar',
  'Amarr' = 'Amarr',
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
};
