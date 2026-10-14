import { getGroupIdByRawGroup } from '@/hooks/Mapper/components/mapInterface/widgets/SystemSignatures/constants';
import { SETTINGS_KEYS, SignatureSettingsType } from '@/hooks/Mapper/constants/signatures';
import { SignatureGroup, SignatureKind, SystemSignature } from '@/hooks/Mapper/types';

const KIND_SETTING_KEYS: Record<SignatureKind, SETTINGS_KEYS> = {
  [SignatureKind.CosmicSignature]: SETTINGS_KEYS.COSMIC_SIGNATURE,
  [SignatureKind.CosmicAnomaly]: SETTINGS_KEYS.COSMIC_ANOMALY,
  [SignatureKind.Structure]: SETTINGS_KEYS.STRUCTURE,
  [SignatureKind.Ship]: SETTINGS_KEYS.SHIP,
  [SignatureKind.Deployable]: SETTINGS_KEYS.DEPLOYABLE,
  [SignatureKind.Drone]: SETTINGS_KEYS.DRONE,
  [SignatureKind.Starbase]: SETTINGS_KEYS.STARBASE,
};

const GROUP_SETTING_KEYS: Partial<Record<SignatureGroup, SETTINGS_KEYS>> = {
  [SignatureGroup.Wormhole]: SETTINGS_KEYS.WORMHOLE,
  [SignatureGroup.GasSite]: SETTINGS_KEYS.GAS_SITE,
  [SignatureGroup.RelicSite]: SETTINGS_KEYS.RELIC_SITE,
  [SignatureGroup.DataSite]: SETTINGS_KEYS.DATA_SITE,
  [SignatureGroup.OreSite]: SETTINGS_KEYS.ORE_SITE,
  [SignatureGroup.CombatSite]: SETTINGS_KEYS.COMBAT_SITE,
};

export const isSignatureEnabledByFilters = (signature: SystemSignature, settings: SignatureSettingsType): boolean => {
  if (!settings[KIND_SETTING_KEYS[signature.kind]]) {
    return false;
  }

  if (!signature.group) {
    return true;
  }

  const mappedGroup = getGroupIdByRawGroup(signature.group);
  if (!mappedGroup || mappedGroup === SignatureGroup.CosmicSignature) {
    return true;
  }

  const groupSettingKey = GROUP_SETTING_KEYS[mappedGroup];
  if (!groupSettingKey) {
    return true;
  }

  return Boolean(settings[groupSettingKey]);
};
