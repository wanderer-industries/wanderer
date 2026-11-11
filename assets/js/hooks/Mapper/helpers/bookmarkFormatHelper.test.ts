import { SignatureGroup, SignatureKind, SystemSignature } from '@/hooks/Mapper/types';
import { WormholeDataRaw } from '@/hooks/Mapper/types/wormholes';
import { formatBookmarkName } from './bookmarkFormatHelper.ts';

// V283: medium hole (size "M"), 3 bil total mass
const WORMHOLES_DATA = {
  V283: { total_mass: 3_000_000_000, max_mass_per_jump: 62_000_000, dest: ['hs'] },
} as unknown as Record<string, WormholeDataRaw>;

const buildSignature = (overrides: Partial<SystemSignature> = {}): SystemSignature => ({
  eve_id: 'ABC-123',
  name: 'ABC-123',
  kind: SignatureKind.CosmicSignature,
  type: 'V283',
  description: '',
  group: SignatureGroup.Wormhole,
  custom_info: '',
  ...overrides,
});

const format = (
  formatStr: string,
  {
    signature = buildSignature(),
    index = 1 as number | string,
    mapping = undefined as Record<string, string> | undefined,
  } = {},
) => formatBookmarkName(formatStr, signature, null, index, WORMHOLES_DATA, false, mapping);

describe('formatBookmarkName', () => {
  describe('without conditional separators', () => {
    it('keeps literal separators around empty variables', () => {
      const signature = buildSignature({ type: 'K162' });

      expect(format('{chain_index} - {sig} - {size} / {mass}', { signature })).toBe('1 - ABC-123 - /');
    });

    it('trims and collapses whitespace', () => {
      const signature = buildSignature({ type: 'K162' });

      expect(format('{chain_index} {size} {sig_letters} ', { signature })).toBe('1 ABC');
    });

    it('preserves leading spaces of the format', () => {
      expect(format('  {chain_index} {sig_letters}')).toBe('  1 ABC');
    });
  });

  describe('with conditional separators', () => {
    const FORMAT = '{chain_index}{? - }{sig}{? - }{size}{? / }{mass}';

    it('renders every separator when every value is present', () => {
      expect(format(FORMAT)).toBe('1 - ABC-123 - M / 3');
    });

    it('drops the separator following an empty trailing value', () => {
      // K162 with unknown destination: no size, no mass
      const signature = buildSignature({ type: 'K162' });

      expect(format(FORMAT, { signature })).toBe('1 - ABC-123');
    });

    it('keeps the first separator when a middle value is empty', () => {
      expect(format(FORMAT, { mapping: { size_medium: '' } })).toBe('1 - ABC-123 - 3');
    });

    it('drops the trailing separator when the last value is empty', () => {
      expect(format('{chain_index}{? - }{sig}{? - }{size}{? / }{description}')).toBe('1 - ABC-123 - M');
    });

    it('drops leading separators when the first values are empty', () => {
      expect(format('{description}{? - }{temporary_name}{? - }{size}{? / }{mass}')).toBe('M / 3');
    });

    it('keeps the first separator when several consecutive values are empty', () => {
      expect(format('{chain_index}{? - }{description}{? | }{temporary_name}{? / }{mass}')).toBe('1 - 3');
    });

    it('returns an empty string when every value is empty', () => {
      expect(format('{description}{? - }{temporary_name}')).toBe('');
    });

    it('handles adjacent separators', () => {
      expect(format('{chain_index}{? - }{? - }')).toBe('1');
      expect(format('{? - }{? - }{chain_index}')).toBe('1');
      expect(format('{chain_index}{? - }{? / }{?|}{sig_letters}')).toBe('1 - ABC');
    });

    it('ignores a format made of separators only', () => {
      expect(format('{? - }{? / }')).toBe('');
    });

    it('treats literal text as a value', () => {
      expect(format('WH{? - }{description}{? - }{size}')).toBe('WH - M');
    });

    it('treats a group of variables as a single value', () => {
      expect(format('{sig_letters} {description}{? - }{size}')).toBe('ABC - M');
    });

    it('treats a whitespace-only segment as empty', () => {
      expect(format('{chain_index}{? - }{description} {temporary_name}{? / }{mass}')).toBe('1 - 3');
    });

    it('supports any separator text', () => {
      expect(format('{chain_index}{? => }{sig_letters}{?|}{size}{?}{mass}')).toBe('1 => ABC|M3');
    });

    it('can be mixed with literal separators', () => {
      const signature = buildSignature({ type: 'K162' });

      expect(format('{chain_index} - {sig_letters}{? / }{size}', { signature })).toBe('1 - ABC');
    });

    it('preserves leading spaces of the format', () => {
      expect(format(' {description}{? - }{sig_letters}')).toBe(' ABC');
    });
  });
});
