import { SETTINGS_KEYS, SignatureSettingsType } from '@/hooks/Mapper/constants/signatures';
import { SignatureGroup, SignatureKind, SystemSignature } from '@/hooks/Mapper/types';
import { isSignatureEnabledByFilters } from './isSignatureEnabledByFilters';

const createSignature = (kind: SignatureKind, group: SignatureGroup): SystemSignature => ({
  eve_id: 'ABC-123',
  kind,
  group,
  name: 'Test signature',
  type: '',
});

describe('isSignatureEnabledByFilters', () => {
  it('hides combat anomalies when the combat site group is disabled', () => {
    const settings: SignatureSettingsType = {
      [SETTINGS_KEYS.COSMIC_ANOMALY]: true,
      [SETTINGS_KEYS.COMBAT_SITE]: false,
    };

    expect(
      isSignatureEnabledByFilters(createSignature(SignatureKind.CosmicAnomaly, SignatureGroup.CombatSite), settings),
    ).toBe(false);
  });

  it('shows combat anomalies when both their kind and group are enabled', () => {
    const settings: SignatureSettingsType = {
      [SETTINGS_KEYS.COSMIC_ANOMALY]: true,
      [SETTINGS_KEYS.COMBAT_SITE]: true,
    };

    expect(
      isSignatureEnabledByFilters(createSignature(SignatureKind.CosmicAnomaly, SignatureGroup.CombatSite), settings),
    ).toBe(true);
  });

  it('hides a signature when its kind is disabled even if its group is enabled', () => {
    const settings: SignatureSettingsType = {
      [SETTINGS_KEYS.COSMIC_ANOMALY]: false,
      [SETTINGS_KEYS.COMBAT_SITE]: true,
    };

    expect(
      isSignatureEnabledByFilters(createSignature(SignatureKind.CosmicAnomaly, SignatureGroup.CombatSite), settings),
    ).toBe(false);
  });

  it('does not apply the cosmic signature fallback group to other kinds', () => {
    const settings: SignatureSettingsType = {
      [SETTINGS_KEYS.SHIP]: true,
      [SETTINGS_KEYS.COSMIC_SIGNATURE]: false,
    };

    expect(
      isSignatureEnabledByFilters(createSignature(SignatureKind.Ship, SignatureGroup.CosmicSignature), settings),
    ).toBe(true);
  });
});
