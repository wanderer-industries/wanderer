import { SignatureGroup, SignatureKind } from '@/hooks/Mapper/types';
import type { ExtendedSystemSignature } from '@/hooks/Mapper/types';
import { getSignatureUpdateGlows } from './getSignatureUpdateGlows';

const SYSTEM_ID = '31000001';

const createSignature = (
  eveId: string,
  updatedAt: string,
  overrides: Partial<ExtendedSystemSignature> = {},
): ExtendedSystemSignature => ({
  eve_id: eveId,
  kind: SignatureKind.CosmicSignature,
  group: SignatureGroup.CosmicSignature,
  name: 'Unknown',
  type: '',
  updated_at: updatedAt,
  ...overrides,
});

describe('getSignatureUpdateGlows', () => {
  it('marks newly received signatures as new', () => {
    const glows = getSignatureUpdateGlows([], [createSignature('ABC-123', '2026-10-12T10:00:00Z')], SYSTEM_ID);

    expect(glows.get('ABC-123')).toEqual({ isNew: true, systemId: SYSTEM_ID });
  });

  it('marks signatures with a changed update timestamp as existing', () => {
    const previous = [createSignature('ABC-123', '2026-10-12T10:00:00Z')];
    const next = [createSignature('ABC-123', '2026-10-12T10:01:00Z')];

    expect(getSignatureUpdateGlows(previous, next, SYSTEM_ID).get('ABC-123')).toEqual({
      isNew: false,
      systemId: SYSTEM_ID,
    });
  });

  it('ignores unchanged and deleted signatures', () => {
    const previous = [createSignature('ABC-123', '2026-10-12T10:00:00Z')];
    const next = [
      createSignature('ABC-123', '2026-10-12T10:00:00Z'),
      createSignature('DEF-456', '2026-10-12T10:01:00Z', { deleted: true }),
    ];

    expect(getSignatureUpdateGlows(previous, next, SYSTEM_ID).size).toBe(0);
  });
});
