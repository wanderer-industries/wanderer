import { GroupType, SignatureGroup } from '@/hooks/Mapper/types';

export const TIME_ONE_MINUTE = 1000 * 60;
export const TIME_TEN_MINUTES = 1000 * 60 * 10;

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
