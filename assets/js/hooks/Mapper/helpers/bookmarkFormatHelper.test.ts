import { calculateBookmarkIndex, handleAutoBookmark } from './bookmarkFormatHelper';
import { parseSignatureCustomInfo } from './parseSignatureCustomInfo';
import { SignatureGroup, SignatureKind, SystemSignature } from '@/hooks/Mapper/types';

const signature = (eve_id: string, custom_info?: string): SystemSignature => ({
  eve_id,
  custom_info,
  kind: SignatureKind.CosmicSignature,
  group: SignatureGroup.Wormhole,
  name: '',
  type: '',
});

const settings = {
  bookmark_auto_temp_name: 'chain_index',
  system_auto_tag: 'chain_index',
};

const autoBookmark = (tag: string | null, systemSignatures: Record<string, SystemSignature[]> = {}, overrides = {}) =>
  handleAutoBookmark(
    signature('NEW-100'),
    { ...settings, ...overrides },
    systemSignatures,
    'current',
    '31000011',
    {},
    null,
    undefined,
    undefined,
    undefined,
    tag,
  );

describe('numeric chain indices after reload', () => {
  it('continues the 00 -> 1 -> 11 chain without cached parent signatures', async () => {
    const { updatedSignature } = await autoBookmark('11');
    expect(updatedSignature.temporary_name).toBe('111');
    expect(parseSignatureCustomInfo(updatedSignature.custom_info).bookmark_index_chained).toBe('111');
  });

  it('skips indices already used by fetched signatures', async () => {
    const { updatedSignature } = await autoBookmark('11', {
      current: [signature('OLD-100', JSON.stringify({ bookmark_index: 1, bookmark_index_chained: '111' }))],
    });
    expect(updatedSignature.temporary_name).toBe('112');
  });

  it('preserves the configured separator', async () => {
    const { updatedSignature } = await autoBookmark('1-1', {}, { bookmark_custom_mapping: { chain_separator: '-' } });
    expect(updatedSignature.temporary_name).toBe('1-1-1');
  });

  it.each(['0', '00', '', 'home', '11-home', null])('does not use the root or a non-chain tag %j', async tag => {
    const { updatedSignature } = await autoBookmark(tag);
    expect(updatedSignature.temporary_name).toBe('1');
  });

  it('does not treat a sequential system tag as a chain prefix', async () => {
    const { updatedSignature } = await autoBookmark('11', {}, { system_auto_tag: 'index' });
    expect(updatedSignature.temporary_name).toBe('1');
  });

  it('honors zero-based indices', async () => {
    const { updatedSignature } = await autoBookmark('11', {}, { bookmark_wormholes_start_at_zero: true });
    expect(updatedSignature.temporary_name).toBe('110');
  });

  it('prefers a loaded parent signature to the system tag', () => {
    const parent = {
      ...signature(
        'PWZ-100',
        JSON.stringify({ bookmark_index: 2, bookmark_index_chained: '12', bookmark_index_chained_letters: 'AB' }),
      ),
      inserted_at: '2026-08-19T00:00:00Z',
      linked_system: { solar_system_id: 31000011 },
    } as SystemSignature;
    expect(calculateBookmarkIndex({ parent: [parent] }, 'current', '31000011', 'NEW-100', false, '', '11')).toEqual({
      index: 1,
      chained: '121',
      chainedLetters: 'AB1',
    });
  });
});
