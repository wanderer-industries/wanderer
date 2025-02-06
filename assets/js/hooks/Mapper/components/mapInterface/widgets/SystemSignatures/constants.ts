import {
  GroupType,
  SignatureGroup,
  SignatureGroupENG,
  SignatureGroupRU,
  SignatureKind,
  SignatureKindENG,
  SignatureKindRU,
} from '@/hooks/Mapper/types';

export const TIME_ONE_MINUTE = 1000 * 60;
export const TIME_TEN_MINUTES = 1000 * 60 * 10;
export const TIME_ONE_DAY = 24 * 60 * 60 * 1000;
export const TIME_ONE_WEEK = 7 * TIME_ONE_DAY;

export const GROUPS_LIST = [
  SignatureGroup.GasSite,
  SignatureGroup.RelicSite,
  SignatureGroup.DataSite,
  SignatureGroup.OreSite,
  SignatureGroup.CombatSite,
  SignatureGroup.Wormhole,
  SignatureGroup.CosmicSignature,
];

const wh = { w: 14, h: 14 };

export const GROUPS: Record<SignatureGroup, GroupType> = {
  [SignatureGroup.GasSite]: { id: SignatureGroup.GasSite, icon: '/icons/brackets/harvestableCloud.png', ...wh },
  [SignatureGroup.RelicSite]: { id: SignatureGroup.RelicSite, icon: '/icons/brackets/relic_Site_16.png', ...wh },
  [SignatureGroup.DataSite]: { id: SignatureGroup.DataSite, icon: '/icons/brackets/data_Site_16.png', ...wh },
  [SignatureGroup.OreSite]: { id: SignatureGroup.OreSite, icon: '/icons/brackets/ore_Site_16.png', ...wh },
  [SignatureGroup.CombatSite]: { id: SignatureGroup.CombatSite, icon: '/icons/brackets/combatSite_16.png', ...wh },
  [SignatureGroup.Wormhole]: { id: SignatureGroup.Wormhole, icon: '/icons/brackets/wormhole.png', ...wh },
  [SignatureGroup.CosmicSignature]: { id: SignatureGroup.CosmicSignature, icon: '/icons/x_close14.png', w: 9, h: 9 },
};

export const MAPPING_GROUP_TO_ENG = {
  // ENGLISH
  [SignatureGroupENG.GasSite]: SignatureGroup.GasSite,
  [SignatureGroupENG.RelicSite]: SignatureGroup.RelicSite,
  [SignatureGroupENG.DataSite]: SignatureGroup.DataSite,
  [SignatureGroupENG.OreSite]: SignatureGroup.OreSite,
  [SignatureGroupENG.CombatSite]: SignatureGroup.CombatSite,
  [SignatureGroupENG.Wormhole]: SignatureGroup.Wormhole,
  [SignatureGroupENG.CosmicSignature]: SignatureGroup.CosmicSignature,

  // RUSSIAN
  [SignatureGroupRU.GasSite]: SignatureGroup.GasSite,
  [SignatureGroupRU.RelicSite]: SignatureGroup.RelicSite,
  [SignatureGroupRU.DataSite]: SignatureGroup.DataSite,
  [SignatureGroupRU.OreSite]: SignatureGroup.OreSite,
  [SignatureGroupRU.CombatSite]: SignatureGroup.CombatSite,
  [SignatureGroupRU.Wormhole]: SignatureGroup.Wormhole,
  [SignatureGroupRU.CosmicSignature]: SignatureGroup.CosmicSignature,
};

export const MAPPING_TYPE_TO_ENG = {
  // ENGLISH
  [SignatureKindENG.CosmicSignature]: SignatureKind.CosmicSignature,
  [SignatureKindENG.CosmicAnomaly]: SignatureKind.CosmicAnomaly,
  [SignatureKindENG.Structure]: SignatureKind.Structure,
  [SignatureKindENG.Ship]: SignatureKind.Ship,
  [SignatureKindENG.Deployable]: SignatureKind.Deployable,
  [SignatureKindENG.Drone]: SignatureKind.Drone,

  // RUSSIAN
  [SignatureKindRU.CosmicSignature]: SignatureKind.CosmicSignature,
  [SignatureKindRU.CosmicAnomaly]: SignatureKind.CosmicAnomaly,
  [SignatureKindRU.Structure]: SignatureKind.Structure,
  [SignatureKindRU.Ship]: SignatureKind.Ship,
  [SignatureKindRU.Deployable]: SignatureKind.Deployable,
  [SignatureKindRU.Drone]: SignatureKind.Drone,
};

export const getGroupIdByRawGroup = (val: string) => MAPPING_GROUP_TO_ENG[val as SignatureGroup];
