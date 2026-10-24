import { SignatureGroup, SignatureKind, SystemSignature } from '@/hooks/Mapper/types';
import { parseSignatures } from '@/hooks/Mapper/helpers';
import { formatSignaturesForClipboard } from './formatSignaturesForClipboard';

const SIGNATURES: SystemSignature[] = [
  {
    eve_id: 'AZU-716',
    kind: SignatureKind.CosmicSignature,
    group: SignatureGroup.CosmicSignature,
    name: 'Unknown',
    type: '',
  },
  {
    eve_id: 'ABC-123',
    kind: SignatureKind.CosmicSignature,
    group: SignatureGroup.Wormhole,
    name: 'Нестабильная червоточина',
    type: '',
  },
  {
    eve_id: 'DEF-456',
    kind: SignatureKind.CosmicAnomaly,
    group: SignatureGroup.CombatSite,
    name: 'Combat Site',
    type: '',
  },
];

describe('formatSignaturesForClipboard', () => {
  it('restores six-column scanner rows and preserves localized signature names', () => {
    expect(formatSignaturesForClipboard(SIGNATURES)).toBe(
      'AZU-716\tCosmic Signature\t\t\t0,0%\t0 m\n' +
        'ABC-123\tCosmic Signature\tWormhole\tНестабильная червоточина\t0,0%\t0 m\n' +
        'DEF-456\tCosmic Anomaly\tCombat Site\tCombat Site\t0,0%\t0 m',
    );
  });

  it('produces text that can be parsed back into the same signatures', () => {
    const clipboardText = formatSignaturesForClipboard(SIGNATURES);

    expect(parseSignatures(clipboardText, Object.values(SignatureKind))).toEqual(SIGNATURES);
  });
});
