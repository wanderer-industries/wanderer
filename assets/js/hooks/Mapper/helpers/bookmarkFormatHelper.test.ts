import {
  isValidBookmarkIndex,
  calculateBookmarkIndex,
  formatBookmarkName,
  handleAutoBookmark,
  applySystemAutoTags,
  executeLinkSignatureToSystem,
  executeSaveSignatureSettings,
  executeManualConnectionAutoTag,
  SignatureSettingsFormValues,
} from './bookmarkFormatHelper';
import { parseSignatures } from './parseSignatures';
import { LabelsManager } from '@/hooks/Mapper/utils/labelsManager';
import { getSystemStaticInfo } from '@/hooks/Mapper/mapRootProvider/hooks/useLoadSystemStatic';
import {
  SystemSignature,
  SignatureKind,
  SignatureGroup,
  UserSettings,
  WormholeDataRaw,
  OutCommand,
  OutCommandHandler,
} from '@/hooks/Mapper/types';
import { SolarSystemRawType } from '@/hooks/Mapper/types/system';
import { SolarSystemConnection, TimeStatus, MassState, ShipSizeStatus } from '@/hooks/Mapper/types/connection';

jest.mock('@/hooks/Mapper/mapRootProvider/hooks/useLoadSystemStatic', () => ({
  getSystemStaticInfo: jest.fn(),
}));

const createMockSystem = (overrides: Partial<SolarSystemRawType> & { id: string }): SolarSystemRawType => ({
  position: { x: 0, y: 0 },
  description: null,
  labels: null,
  locked: false,
  tag: null,
  status: 0,
  name: null,
  temporary_name: null,
  linked_sig_eve_id: null,
  comments_count: null,
  system_static_info: {
    region_id: 0,
    constellation_id: 0,
    solar_system_id: 0,
    solar_system_name: '',
    solar_system_name_lc: '',
    constellation_name: '',
    region_name: '',
    system_class: 0,
    security: '',
    type_description: '',
    class_title: '',
    is_shattered: false,
    effect_name: '',
    effect_power: 0,
    statics: [],
    wandering: [],
    triglavian_invasion_status: '',
    sun_type_id: 0,
  },
  system_signatures: [],
  ...overrides,
});

const createMockConnection = (
  overrides: Partial<SolarSystemConnection> & { id: string; source: string; target: string },
): SolarSystemConnection => ({
  time_status: TimeStatus.reserved,
  mass_status: MassState.normal,
  ship_size_type: ShipSizeStatus.small,
  locked: false,
  ...overrides,
});

const createMockSignature = (overrides: Partial<SystemSignature> & { eve_id: string }): SystemSignature => ({
  kind: SignatureKind.CosmicSignature,
  name: '',
  group: SignatureGroup.Wormhole,
  type: '',
  ...overrides,
});

describe('bookmarkFormatHelper', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('isValidBookmarkIndex', () => {
    it('should validate standard numeric indexes', () => {
      expect(isValidBookmarkIndex('1')).toBe(true);
      expect(isValidBookmarkIndex('12')).toBe(true);
    });

    it('should validate letter-digit combinations with maximum 2 letters', () => {
      expect(isValidBookmarkIndex('A1')).toBe(true);
      expect(isValidBookmarkIndex('A11')).toBe(true);
      expect(isValidBookmarkIndex('AB1')).toBe(true);
      expect(isValidBookmarkIndex('ABC1')).toBe(false); // 3 letters is invalid
    });

    it('should validate single or double letters', () => {
      expect(isValidBookmarkIndex('A')).toBe(true);
      expect(isValidBookmarkIndex('AB')).toBe(true);
      expect(isValidBookmarkIndex('ABC')).toBe(false); // 3 letters is invalid
    });

    it('should handle custom separators correctly', () => {
      expect(isValidBookmarkIndex('A-1', '-')).toBe(true);
      expect(isValidBookmarkIndex('A-B-1', '-')).toBe(true);
      expect(isValidBookmarkIndex('Home-1', '-')).toBe(false); // 'Home' part is invalid
      expect(isValidBookmarkIndex('A-1', '')).toBe(false); // Invalid without separator due to hyphen
    });

    it('should reject non-standard label strings like Home or Danger', () => {
      expect(isValidBookmarkIndex('Home')).toBe(false);
      expect(isValidBookmarkIndex('Danger')).toBe(false);
      expect(isValidBookmarkIndex('HUB')).toBe(false);
      expect(isValidBookmarkIndex('1H')).toBe(false);
      expect(isValidBookmarkIndex('2B')).toBe(false);
    });
  });

  describe('calculateBookmarkIndex', () => {
    const mockSignatures: Record<string, SystemSignature[]> = {};

    it('should use a systems custom label or tag if standard', () => {
      (getSystemStaticInfo as jest.Mock).mockReturnValue({ solar_system_id: 30000142 });

      const systems: SolarSystemRawType[] = [
        createMockSystem({
          id: 'sys1',
          tag: 'A',
          labels: 'customLabel:A',
          temporary_name: 'sys-1',
        }),
      ];

      const result = calculateBookmarkIndex(mockSignatures, 'sys1', 'sys1', 'sig1', false, '-', systems, []);

      // Since the system itself is the start node and has a valid tag 'A', it should be treated as parent index
      expect(result.chained).toBe('A-1');
      expect(result.index).toBe(1);
    });

    it('should skip non-standard custom labels/tags during topology tracing', () => {
      (getSystemStaticInfo as jest.Mock).mockReturnValue({ solar_system_id: 30000142 });

      const systems: SolarSystemRawType[] = [
        createMockSystem({
          id: 'sys_parent',
          tag: 'A',
        }),
        createMockSystem({
          id: 'sys_child_1',
          tag: 'Home', // non-standard, should be ignored
        }),
        createMockSystem({
          id: 'sys_child_2',
          tag: '',
        }),
      ];

      const connections: SolarSystemConnection[] = [
        createMockConnection({
          id: 'conn1',
          source: 'sys_parent',
          target: 'sys_child_1',
        }),
        createMockConnection({
          id: 'conn2',
          source: 'sys_child_1',
          target: 'sys_child_2',
        }),
      ];

      const result = calculateBookmarkIndex(
        mockSignatures,
        'sys_child_2',
        'sys_child_2',
        'sig2',
        false,
        '-',
        systems,
        connections,
      );

      // sys_child_2 parent is sys_child_1. Since sys_child_1's tag 'Home' is non-standard,
      // it should continue searching upstream to sys_parent whose tag is 'A' (which is valid).
      // sys_child_1 is child 1 of sys_parent -> index is 1.
      // sys_child_2 is child 1 of sys_child_1 -> index is 1.
      // Since sys_child_1's own label 'Home' is skipped, the chain index at sys_child_1 resolves to 'A-1'.
      // Therefore, sys_child_2 should be resolved to 'A-1-1', and its signature's index is 'A-1-1-1'.
      expect(result.chained).toBe('A-1-1-1');
    });

    it('should correctly avoid collision with existing tags in local chain systems', () => {
      const systems: SolarSystemRawType[] = [
        createMockSystem({
          id: 'sys_parent',
          tag: 'B',
        }),
        createMockSystem({
          id: 'sys_child_1',
          tag: 'B-1',
        }),
        createMockSystem({
          id: 'sys_child_2',
          tag: '',
        }),
      ];

      const connections: SolarSystemConnection[] = [
        createMockConnection({
          id: 'conn1',
          source: 'sys_parent',
          target: 'sys_child_1',
        }),
        createMockConnection({
          id: 'conn2',
          source: 'sys_parent',
          target: 'sys_child_2',
        }),
      ];

      const result = calculateBookmarkIndex(
        mockSignatures,
        'sys_child_2',
        'sys_child_2',
        'sig2',
        false,
        '-',
        systems,
        connections,
      );

      // sys_child_2's parent is sys_parent ('B').
      // Sibling sys_child_1 already has tag 'B-1'.
      // So the generated candidate index 'B-1' collides with existing 'B-1' in the local chain systems.
      // It must increment to find the next available index 'B-2', and its signature's index is 'B-2-1'.
      expect(result.chained).toBe('B-2-1');
      expect(result.index).toBe(1);
    });

    it('should not collide with its own linked target system tag/label', () => {
      const systems: SolarSystemRawType[] = [
        createMockSystem({
          id: 'sys_parent',
          tag: 'B',
        }),
        createMockSystem({
          id: 'sys_child_1',
          tag: 'B-1',
          linked_sig_eve_id: 'sig1',
        }),
      ];

      const connections: SolarSystemConnection[] = [
        createMockConnection({
          id: 'conn1',
          source: 'sys_parent',
          target: 'sys_child_1',
        }),
      ];

      const result = calculateBookmarkIndex(
        mockSignatures,
        'sys_parent',
        'sys_parent',
        'sig1',
        false,
        '-',
        systems,
        connections,
      );

      // sys_child_1's tag 'B-1' should be excluded from collision check because it's linked to 'sig1'.
      // So the result should be 'B-1' and index 1 instead of incrementing to 'B-2'.
      expect(result.chained).toBe('B-1');
      expect(result.index).toBe(1);
    });

    it('should ignore deleted signatures when checking for collisions', () => {
      const systems: SolarSystemRawType[] = [
        createMockSystem({
          id: 'sys_parent',
          tag: 'B',
        }),
        createMockSystem({
          id: 'sys_child_1',
          tag: 'B-1',
          linked_sig_eve_id: 'sig1',
        }),
      ];

      const connections: SolarSystemConnection[] = [
        createMockConnection({
          id: 'conn1',
          source: 'sys_parent',
          target: 'sys_child_1',
        }),
      ];

      const signatures: Record<string, SystemSignature[]> = {
        sys_parent: [
          createMockSignature({
            eve_id: 'sig1',
            group: SignatureGroup.Wormhole,
            custom_info: JSON.stringify({
              bookmark_index: 1,
              bookmark_index_chained: 'B-1',
              bookmark_index_chained_letters: 'B-1',
            }),
            linked_system: {
              region_id: 0,
              constellation_id: 0,
              solar_system_id: 0,
              solar_system_name: '',
              solar_system_name_lc: '',
              constellation_name: '',
              region_name: '',
              system_class: 0,
              security: '',
              type_description: '',
              class_title: '',
              is_shattered: false,
              effect_name: '',
              effect_power: 0,
              statics: [],
              wandering: [],
              triglavian_invasion_status: '',
              sun_type_id: 0,
            },
          }),
          createMockSignature({
            eve_id: 'sig2',
            group: SignatureGroup.Wormhole,
            deleted: true,
            custom_info: JSON.stringify({
              bookmark_index: 2,
              bookmark_index_chained: 'B-2',
              bookmark_index_chained_letters: 'B-2',
            }),
          }),
        ],
      };

      const result = calculateBookmarkIndex(
        signatures,
        'sys_parent',
        'sys_parent',
        'sig3',
        false,
        '-',
        systems,
        connections,
      );

      // 'B-1' is taken by active child system sys_child_1.
      // 'B-2' should be free because 'sig2' is marked as deleted (even though it has B-2 bookmark info).
      // So the returned result should be 'B-2' and index 2.
      expect(result.chained).toBe('B-2');
      expect(result.index).toBe(2);
    });

    it('should detect letter-chain collisions when parent system is untagged (3G)', () => {
      const systems: SolarSystemRawType[] = [
        createMockSystem({ id: 'sys_home' }),
        createMockSystem({ id: 'sys_a' }),
        createMockSystem({ id: 'sys_a1', tag: 'A-1' }),
      ];

      const connections: SolarSystemConnection[] = [
        createMockConnection({ id: 'c1', source: 'sys_home', target: 'sys_a' }),
        createMockConnection({ id: 'c2', source: 'sys_a', target: 'sys_a1' }),
      ];

      const result = calculateBookmarkIndex({}, 'sys_a', 'sys_a', 'sig_new', false, '-', systems, connections);

      // sys_a resolves to indexStr "1", lettersStr "A".
      // Because sys_a1 already has tag "A-1", candidate 1 ("A-1") collides and increments to 2 ("A-2").
      expect(result.index).toBe(2);
      expect(result.chained).toBe('1-2');
      expect(result.chainedLetters).toBe('A-2');
    });

    it('should detect numeric tag collisions at the root node and include sibling temporary_name (3G, 3H)', () => {
      const systems: SolarSystemRawType[] = [
        createMockSystem({ id: 'sys_home' }),
        createMockSystem({ id: 'sys_child_1', tag: '1' }),
        createMockSystem({ id: 'sys_child_2', temporary_name: 'B' }),
      ];

      const connections: SolarSystemConnection[] = [
        createMockConnection({ id: 'c1', source: 'sys_home', target: 'sys_child_1' }),
        createMockConnection({ id: 'c2', source: 'sys_home', target: 'sys_child_2' }),
      ];

      const result = calculateBookmarkIndex({}, 'sys_home', 'sys_home', 'sig_new', false, '-', systems, connections);

      // Index 1 collides with sys_child_1 tag '1'; Index 2 ('B') collides with sys_child_2 temporary_name 'B'.
      expect(result.index).toBe(3);
      expect(result.chained).toBe('3');
      expect(result.chainedLetters).toBe('C');
    });

    it('should use linked signature bookmark_index from parent systemSignatures before sibling order fallback (3I)', () => {
      const systems: SolarSystemRawType[] = [
        createMockSystem({ id: 'sys_home' }),
        createMockSystem({ id: 'sys_b', linked_sig_eve_id: 'sig2' }),
      ];

      const connections: SolarSystemConnection[] = [
        createMockConnection({ id: 'c1', source: 'sys_home', target: 'sys_b' }),
      ];

      const signatures: Record<string, SystemSignature[]> = {
        sys_home: [
          createMockSignature({
            eve_id: 'sig1',
            group: SignatureGroup.Wormhole,
            linked_system: systems[1].system_static_info,
            custom_info: JSON.stringify({
              bookmark_index: 1,
              bookmark_index_chained: '1',
              bookmark_index_chained_letters: 'A',
            }),
          }),
          createMockSignature({
            eve_id: 'sig2',
            group: SignatureGroup.Wormhole,
            linked_system: systems[1].system_static_info,
            custom_info: JSON.stringify({
              bookmark_index: 2,
              bookmark_index_chained: '2',
              bookmark_index_chained_letters: 'B',
            }),
          }),
        ],
      };

      const result = calculateBookmarkIndex(
        signatures,
        'sys_b',
        'sys_b',
        'sig_child',
        false,
        '-',
        systems,
        connections,
      );

      // Even though sys_b is the only connected child of sys_home, its linked signature is sig2 (index 2 / 'B').
      expect(result.index).toBe(1);
      expect(result.chained).toBe('2-1');
      expect(result.chainedLetters).toBe('B-1');
    });
  });

  describe('handleAutoBookmark', () => {
    it('should calculate bookmark_index when only system_auto_tag is enabled (2F)', async () => {
      const signature = createMockSignature({
        eve_id: 'sig1',
        group: SignatureGroup.Wormhole,
      });

      const settings: UserSettings = {
        system_auto_tag: 'chain_index_letters',
      };

      const systems: SolarSystemRawType[] = [createMockSystem({ id: 'sys_home' })];

      const { updatedSignature, shouldUpdate } = await handleAutoBookmark(
        signature,
        settings,
        {},
        'sys_home',
        'sys_home',
        {},
        null,
        undefined,
        undefined,
        systems,
        [],
      );

      expect(shouldUpdate).toBe(true);
      const info = JSON.parse(updatedSignature.custom_info || '{}');
      expect(info.bookmark_index).toBe(1);
      expect(info.bookmark_index_chained_letters).toBe('A');
    });
  });

  describe('applySystemAutoTags', () => {
    let outCommandMock: jest.Mock;

    beforeEach(() => {
      outCommandMock = jest.fn();
    });

    it('should prioritize temporary_name over computed values if present', async () => {
      const signature = createMockSignature({
        eve_id: 'sig1',
        temporary_name: 'B',
        custom_info: JSON.stringify({
          bookmark_index: 1,
          bookmark_index_chained: 'A-1',
          bookmark_index_chained_letters: 'A-1',
        }),
      });

      const settings: UserSettings = {
        system_auto_tag: 'chain_index_letters',
        system_custom_label_name: 'chain_index_letters',
      };

      const system = createMockSystem({ id: 'sys1', labels: null });

      await applySystemAutoTags(signature, settings, system, outCommandMock);

      expect(outCommandMock).toHaveBeenCalledTimes(2);
      expect(outCommandMock).toHaveBeenNthCalledWith(1, {
        type: 'update_system_tag',
        data: { system_id: 'sys1', value: 'B' },
      });
      expect(outCommandMock).toHaveBeenNthCalledWith(2, {
        type: 'update_system_labels',
        data: {
          system_id: 'sys1',
          value: JSON.stringify({ customLabel: 'B', labels: [''] }),
        },
      });
    });

    it('should fallback to computed bookmark index if temporary_name is absent', async () => {
      const signature = createMockSignature({
        eve_id: 'sig1',
        custom_info: JSON.stringify({
          bookmark_index: 2,
          bookmark_index_chained_letters: 'A-2',
        }),
      });

      const settings: UserSettings = {
        system_auto_tag: 'chain_index_letters',
        system_custom_label_name: 'chain_index_letters',
      };

      const system = createMockSystem({ id: 'sys1', labels: null });

      await applySystemAutoTags(signature, settings, system, outCommandMock);

      expect(outCommandMock).toHaveBeenCalledTimes(2);
      expect(outCommandMock).toHaveBeenNthCalledWith(1, {
        type: 'update_system_tag',
        data: { system_id: 'sys1', value: 'A-2' },
      });
      expect(outCommandMock).toHaveBeenNthCalledWith(2, {
        type: 'update_system_labels',
        data: {
          system_id: 'sys1',
          value: JSON.stringify({ customLabel: 'A-2', labels: [''] }),
        },
      });
    });

    it('should not auto-tag parent/Home system when linking a return hole (2D)', async () => {
      const returnHoleSig = createMockSignature({
        eve_id: 'sig_ret',
        temporary_name: '<',
        custom_info: JSON.stringify({
          bookmark_index_chained: '<',
          bookmark_index_chained_letters: '<',
        }),
      });

      const settings: UserSettings = {
        bookmark_return_hole_ignore: true,
        bookmark_return_hole_symbol: '<',
        bookmark_auto_temp_name: 'chain_index_letters',
        system_auto_tag: 'chain_index_letters',
        system_custom_label_name: 'chain_index_letters',
      };

      const homeSystem = createMockSystem({ id: 'sys_home', tag: 'H', labels: null });

      await applySystemAutoTags(returnHoleSig, settings, homeSystem, outCommandMock);

      expect(outCommandMock).not.toHaveBeenCalled();
    });

    it('should not let bookmark_auto_temp_name clobber system_auto_tag format when auto-generated (2E)', async () => {
      const signature = createMockSignature({
        eve_id: 'sig1',
        temporary_name: '1', // auto-generated by bookmark_auto_temp_name: 'index'
        custom_info: JSON.stringify({
          bookmark_index: 1,
          bookmark_index_chained: '1-1',
          bookmark_index_chained_letters: 'A-1',
        }),
      });

      const settings: UserSettings = {
        bookmark_auto_temp_name: 'index',
        system_auto_tag: 'chain_index_letters',
        system_custom_label_name: 'chain_index',
      };

      const system = createMockSystem({ id: 'sys1', labels: null });

      await applySystemAutoTags(signature, settings, system, outCommandMock);

      expect(outCommandMock).toHaveBeenCalledTimes(2);
      expect(outCommandMock).toHaveBeenNthCalledWith(1, {
        type: 'update_system_tag',
        data: { system_id: 'sys1', value: 'A-1' },
      });
      expect(outCommandMock).toHaveBeenNthCalledWith(2, {
        type: 'update_system_labels',
        data: {
          system_id: 'sys1',
          value: JSON.stringify({ customLabel: '1-1', labels: [''] }),
        },
      });
    });

    it('should not treat empty temporary_name as a return hole when returnHoleSymbol is empty (Issue 8)', async () => {
      const signature = createMockSignature({
        eve_id: 'sig1',
        temporary_name: '',
        custom_info: JSON.stringify({
          bookmark_index: 1,
          bookmark_index_chained: '1',
          bookmark_index_chained_letters: 'A',
        }),
      });

      const settings: UserSettings = {
        bookmark_return_hole_ignore: true,
        bookmark_return_hole_symbol: '',
        system_auto_tag: 'chain_index_letters',
      };

      const system = createMockSystem({ id: 'sys1', labels: null });

      await applySystemAutoTags(signature, settings, system, outCommandMock);

      expect(outCommandMock).toHaveBeenCalledWith({
        type: 'update_system_tag',
        data: { system_id: 'sys1', value: 'A' },
      });
    });
  });

  describe('additional audit fixes', () => {
    it('should convert numeric parent system tag/temp_name to letters for chainedLetters (Issue 9)', () => {
      const systems: SolarSystemRawType[] = [
        createMockSystem({
          id: 'sys1',
          tag: '1',
        }),
      ];

      const result = calculateBookmarkIndex({}, 'sys1', 'sys1', 'sig1', false, '-', systems, []);
      expect(result.chained).toBe('1-1');
      expect(result.chainedLetters).toBe('A-1');
    });

    it('should handle cyclic connections without dropping depth or infinite looping (Issue 11)', () => {
      const systems: SolarSystemRawType[] = [
        createMockSystem({ id: 'sys_root', tag: 'A' }),
        createMockSystem({ id: 'sys_b', tag: null }),
        createMockSystem({ id: 'sys_c', tag: null }),
      ];

      // Cycle: sys_root -> sys_b -> sys_c -> sys_b (even if cyclic edge appears first)
      const connections: SolarSystemConnection[] = [
        createMockConnection({ id: 'c3', source: 'sys_c', target: 'sys_b' }),
        createMockConnection({ id: 'c1', source: 'sys_root', target: 'sys_b' }),
        createMockConnection({ id: 'c2', source: 'sys_b', target: 'sys_c' }),
      ];

      const result = calculateBookmarkIndex({}, 'sys_c', 'sys_c', 'sig1', false, '-', systems, connections);
      expect(result.chainedLetters).toBe('A-1-1-1');
    });

    it('should format {size}, {mass}, {dest_class_index}, and avoid recursive token expansion (Issues 3, 4, 5, 6)', () => {
      const wormholesData: Record<string, Partial<WormholeDataRaw>> = {
        H900: { max_mass_per_jump: 375000000, total_mass: 3000000000, dest: ['c5'] },
        Z971: { max_mass_per_jump: 62000000, total_mass: 100000000, dest: ['c1'] },
        A009: { max_mass_per_jump: 5000000, total_mass: 500000000, dest: ['c13'] },
        H296: { max_mass_per_jump: 1000000000, total_mass: 3000000000, dest: ['c5'] },
        C729: { max_mass_per_jump: 1000000000, total_mass: 2000000000, dest: ['pochven'] },
      };

      // K162 with destType ('c5' -> whClassName 'H900') defaults to Large ('') rather than Medium ('M')
      const k162Sig = createMockSignature({
        eve_id: 'ABC-123',
        type: 'K162',
        custom_info: JSON.stringify({
          destType: 'c5',
          bookmark_index: 1,
          bookmark_index_chained: '1',
          bookmark_index_chained_letters: 'A',
        }),
      });

      const formattedK162 = formatBookmarkName('{size} {mass} {chain_index_letters}', k162Sig, null, 1, wormholesData);
      expect(formattedK162).toBe('3 A');

      // K162 leading to C1 defaults to Medium ('M'), and C13 defaults to Small ('S')
      const k162C1Sig = createMockSignature({
        eve_id: 'ABC-124',
        type: 'K162',
        custom_info: JSON.stringify({ destType: 'c1' }),
      });
      expect(formatBookmarkName('{size} {dest_type}', k162C1Sig, null, 1, wormholesData)).toBe('M C1');

      const k162C13Sig = createMockSignature({
        eve_id: 'ABC-125',
        type: 'K162',
        custom_info: JSON.stringify({ destType: 'c13' }),
      });
      expect(formatBookmarkName('{size} {dest_type}', k162C13Sig, null, 1, wormholesData)).toBe('S C13');

      // K162 linked to a system without explicit destType in custom_info still resolves size from target class
      const k162LinkedToC1 = createMockSignature({
        eve_id: 'ABC-126',
        type: 'K162',
        custom_info: JSON.stringify({}),
      });
      expect(formatBookmarkName('{size} {dest_type}', k162LinkedToC1, 'C1', 1, wormholesData)).toBe('M C1');
      expect(formatBookmarkName('{size} {dest_type}', k162LinkedToC1, 'C5', 1, wormholesData)).toBe('C5');

      // C729 (in MULTI_DEST_WHS, non-K162) should look up wormholesData['C729'] directly
      const c729Sig = createMockSignature({
        eve_id: 'DEF-456',
        type: 'C729',
        custom_info: JSON.stringify({
          destType: 't',
          bookmark_index: 1,
        }),
      });

      const formattedC729 = formatBookmarkName('{size}', c729Sig, null, 1, wormholesData);
      expect(formattedC729).toBe('XL');

      // Single-pass token replacement: custom mapping containing {type} should not expand {type}
      const recursiveMappingSig = createMockSignature({
        eve_id: 'GHI-789',
        type: 'H296',
        custom_info: JSON.stringify({
          destType: 'c5',
          bookmark_index: 1,
        }),
      });

      const formattedSinglePass = formatBookmarkName(
        '{dest_type} {type}',
        recursiveMappingSig,
        'C5',
        1,
        wormholesData,
        false,
        { class_c5: '{type}' },
      );
      expect(formattedSinglePass).toBe('{type} H296');
    });

    it('resolves correct default hole sizes across all destination classes using real wormholes.json data', () => {
      // eslint-disable-next-line @typescript-eslint/no-var-requires
      const rawWormholes = require('../../../../../priv/repo/data/wormholes.json') as WormholeDataRaw[];
      const realWormholesData: Record<string, Partial<WormholeDataRaw>> = Object.fromEntries(
        rawWormholes.map(wh => [wh.name, wh]),
      );

      const expectedSizesByDestType: Record<string, string> = {
        hs: '',
        ls: '',
        ns: '',
        c1: 'M',
        c2: '',
        c3: '',
        c4: '',
        c5: '',
        c6: '',
        c13: 'S',
        thera: '',
        pochven: '',
        c1_c2_c3: '',
        c4_c5: '',
      };

      for (const [destType, expectedSize] of Object.entries(expectedSizesByDestType)) {
        const sig = createMockSignature({
          eve_id: 'K16-200',
          type: 'K162',
          custom_info: JSON.stringify({ destType }),
        });
        expect(formatBookmarkName('{size}', sig, null, 1, realWormholesData)).toBe(expectedSize);
        expect(formatBookmarkName('{size}', sig, null, 1, realWormholesData, false, { size_large: 'L' })).toBe(
          expectedSize || 'L',
        );
      }

      // When current system is C1 or C13, K162 to C5 should be constrained to Medium ('M') or Small ('S')
      (getSystemStaticInfo as jest.Mock).mockImplementation((id?: string | number) => {
        if (id === 'sys_c1') return { system_class: 1 };
        if (id === 'sys_c13') return { system_class: 13 };
        return undefined;
      });
      const k162ToC5 = createMockSignature({
        eve_id: 'K16-205',
        type: 'K162',
        custom_info: JSON.stringify({ destType: 'c5' }),
      });
      expect(
        formatBookmarkName('{size}', k162ToC5, null, 1, realWormholesData, false, undefined, undefined, 'sys_c1'),
      ).toBe('M');
      expect(
        formatBookmarkName('{size}', k162ToC5, null, 1, realWormholesData, false, undefined, undefined, 'sys_c13'),
      ).toBe('S');
    });

    it('should update auto-generated temporary_name when chain index changes (Issue 13)', async () => {
      const systems: SolarSystemRawType[] = [createMockSystem({ id: 'sys_parent', tag: 'A' })];
      const sig = createMockSignature({
        eve_id: 'sig1',
        temporary_name: 'A', // previously auto-generated at root with chain_index_letters
        custom_info: JSON.stringify({
          bookmark_index: 1,
          bookmark_index_chained: '1',
          bookmark_index_chained_letters: 'A',
        }),
      });

      const settings: UserSettings = {
        bookmark_auto_temp_name: 'chain_index_letters',
        system_auto_tag: 'chain_index_letters',
        bookmark_custom_mapping: { chain_separator: '-' },
      };

      const { updatedSignature, shouldUpdate } = await handleAutoBookmark(
        sig,
        settings,
        { sys_parent: [sig] },
        'sys_parent',
        'sys_parent',
        {},
        null,
        undefined,
        undefined,
        systems,
        [],
      );

      expect(shouldUpdate).toBe(true);
      expect(updatedSignature.temporary_name).toBe('A-1');
    });

    it('should not treat an already-linked forward hole as a return hole when a return hole exists in the target system', async () => {
      const systems: SolarSystemRawType[] = [
        createMockSystem({
          id: 'sys_home',
          system_static_info: {
            ...createMockSystem({ id: 'sys_home' }).system_static_info,
            solar_system_id: 30000142,
          },
        }),
        createMockSystem({
          id: 'sys_child',
          linked_sig_eve_id: 'sig_fwd',
          system_static_info: {
            ...createMockSystem({ id: 'sys_child' }).system_static_info,
            solar_system_id: 30000143,
          },
        }),
      ];

      const sigFwd = createMockSignature({
        eve_id: 'sig_fwd',
        group: SignatureGroup.Wormhole,
        temporary_name: 'A',
        inserted_at: '2026-10-24T12:05:00Z',
        linked_system: systems[1].system_static_info,
        custom_info: JSON.stringify({
          bookmark_index: 1,
          bookmark_index_chained: '1',
          bookmark_index_chained_letters: 'A',
        }),
      });

      const sigRet = createMockSignature({
        eve_id: 'sig_ret',
        group: SignatureGroup.Wormhole,
        temporary_name: '<',
        inserted_at: '2026-10-24T12:00:00Z', // even if scanned earlier
        linked_system: systems[0].system_static_info,
        custom_info: JSON.stringify({
          bookmark_index_chained: '<',
          bookmark_index_chained_letters: '<',
        }),
      });

      const settings: UserSettings = {
        bookmark_return_hole_ignore: true,
        bookmark_return_hole_symbol: '<',
        bookmark_auto_temp_name: 'chain_index_letters',
      };

      const { updatedSignature } = await handleAutoBookmark(
        sigFwd,
        settings,
        { sys_home: [sigFwd], sys_child: [sigRet] },
        'sys_home',
        '30000142',
        {},
        null,
        'sys_child',
        '30000143',
        systems,
        [],
      );

      expect(updatedSignature.temporary_name).toBe('A');
      const info = JSON.parse(updatedSignature.custom_info || '{}');
      expect(info.bookmark_index).toBe(1);
    });

    it('should convert multi-hop numeric chain tags ("11") with empty separator to "A1" instead of "K"', () => {
      const systems: SolarSystemRawType[] = [
        createMockSystem({ id: 'sys_home', tag: null }),
        createMockSystem({ id: 'sys_1', tag: '1' }),
        createMockSystem({ id: 'sys_11', tag: '11' }),
      ];

      const connections: SolarSystemConnection[] = [
        createMockConnection({ id: 'c1', source: 'sys_home', target: 'sys_1' }),
        createMockConnection({ id: 'c2', source: 'sys_1', target: 'sys_11' }),
      ];

      const result = calculateBookmarkIndex({}, 'sys_11', 'sys_11', 'sig1', false, '', systems, connections);
      expect(result.chained).toBe('111');
      expect(result.chainedLetters).toBe('A11');
    });

    it('should fall back to getSystemStaticInfo when system_static_info is omitted on initial map load', () => {
      (getSystemStaticInfo as jest.Mock).mockImplementation((id: string | number) => {
        if (id === 'sys_parent') {
          return { solar_system_id: 30000142 };
        }
        if (id === 'sys_child') {
          return { solar_system_id: 30000143 };
        }
        return undefined;
      });

      const parentSys = createMockSystem({ id: 'sys_parent', tag: 'A' });
      const childSys = createMockSystem({ id: 'sys_child', tag: null });
      // Simulate initial map load where system_static_info is omitted from system payload
      delete (parentSys as Partial<SolarSystemRawType>).system_static_info;
      delete (childSys as Partial<SolarSystemRawType>).system_static_info;

      const sigFromParent = createMockSignature({
        eve_id: 'sig_parent_to_child',
        linked_system: {
          ...createMockSystem({ id: 'sys_child' }).system_static_info,
          solar_system_id: 30000143,
        },
        custom_info: JSON.stringify({
          bookmark_index: 2,
          bookmark_index_chained: '12',
          bookmark_index_chained_letters: 'A2',
        }),
      });

      const connections: SolarSystemConnection[] = [
        createMockConnection({ id: 'c1', source: 'sys_parent', target: 'sys_child' }),
      ];

      // Keyed by solar_system_id string ("30000142")
      const result = calculateBookmarkIndex(
        { '30000142': [sigFromParent] },
        'sys_child',
        '30000143',
        'sig_new',
        false,
        '',
        [parentSys, childSys],
        connections,
      );

      expect(result.chained).toBe('A21');
      expect(result.chainedLetters).toBe('A21');
    });

    it('should preserve full chain path when systems have single-hop or letter-chain tags from linked signatures', () => {
      const systems: SolarSystemRawType[] = [
        createMockSystem({ id: 'sys_home' }),
        createMockSystem({ id: 'sys_a', tag: 'A', linked_sig_eve_id: 'sig_h_a' }),
        createMockSystem({ id: 'sys_a1', temporary_name: '1', linked_sig_eve_id: 'sig_a_a1' }),
      ];

      const connections: SolarSystemConnection[] = [
        createMockConnection({ id: 'c1', source: 'sys_home', target: 'sys_a' }),
        createMockConnection({ id: 'c2', source: 'sys_a', target: 'sys_a1' }),
      ];

      const signatures: Record<string, SystemSignature[]> = {
        sys_home: [
          createMockSignature({
            eve_id: 'sig_h_a',
            custom_info: JSON.stringify({
              bookmark_index: 1,
              bookmark_index_chained: '1',
              bookmark_index_chained_letters: 'A',
            }),
          }),
        ],
        sys_a: [
          createMockSignature({
            eve_id: 'sig_a_a1',
            custom_info: JSON.stringify({
              bookmark_index: 1,
              bookmark_index_chained: '11',
              bookmark_index_chained_letters: 'A1',
            }),
          }),
        ],
      };

      const result = calculateBookmarkIndex(signatures, 'sys_a1', 'sys_a1', 'sig_new', false, '', systems, connections);

      expect(result.index).toBe(1);
      expect(result.chained).toBe('111');
      expect(result.chainedLetters).toBe('A11');
    });

    it('should replace return hole temporary_name when re-linked to a forward system', async () => {
      const systems: SolarSystemRawType[] = [
        createMockSystem({ id: 'sys_home' }),
        createMockSystem({ id: 'sys_forward' }),
      ];

      const previouslyReturnSig = createMockSignature({
        eve_id: 'sig1',
        group: SignatureGroup.Wormhole,
        temporary_name: '<',
        custom_info: JSON.stringify({
          bookmark_index_chained: '<',
          bookmark_index_chained_letters: '<',
        }),
      });

      const settings: UserSettings = {
        bookmark_return_hole_ignore: true,
        bookmark_return_hole_symbol: '<',
        bookmark_auto_temp_name: 'chain_index_letters',
        system_auto_tag: 'chain_index_letters',
      };

      const { updatedSignature, shouldUpdate } = await handleAutoBookmark(
        previouslyReturnSig,
        settings,
        { sys_home: [previouslyReturnSig] },
        'sys_home',
        'sys_home',
        {},
        null,
        'sys_forward',
        'sys_forward',
        systems,
        [],
      );

      expect(shouldUpdate).toBe(true);
      expect(updatedSignature.temporary_name).toBe('A');
      const info = JSON.parse(updatedSignature.custom_info || '{}');
      expect(info.bookmark_index).toBe(1);
    });
  });

  describe('Full Multi-User & Multi-Chain Workflow Integration (Options 1 + 3)', () => {
    /**
     * Generic stateful simulator that mirrors the Elixir MapServer / EventHandlers
     * and drives the real frontend orchestration functions:
     * - parseSignatures (clipboard paste)
     * - executeSaveSignatureSettings (SignatureSettings modal save)
     * - executeLinkSignatureToSystem (useLinkSignature splash/dialog link)
     * - executeManualConnectionAutoTag (MapWrapper manual connection auto-tag)
     */
    class MapWorkflowSimulator {
      public systems: SolarSystemRawType[] = [];
      public connections: SolarSystemConnection[] = [];
      public systemSignatures: Record<string, SystemSignature[]> = {};
      public wormholesData: Record<string, Partial<WormholeDataRaw>> = {
        C247: { dest: ['c3'], max_mass_per_jump: 300000000, total_mass: 2000000000 },
        H296: { dest: ['c5'], max_mass_per_jump: 1350000000, total_mass: 3000000000 },
        X877: { dest: ['c4'], max_mass_per_jump: 300000000, total_mass: 2000000000 },
        D845: { dest: ['hs'], max_mass_per_jump: 300000000, total_mass: 5000000000 },
        K162: { dest: [], max_mass_per_jump: 300000000, total_mass: 2000000000 },
      };
      public userSettingsByUser: Record<string, UserSettings> = {};
      public activeUser: string = 'default';
      public commandLog: Array<{ user: string; type: OutCommand; data: unknown }> = [];
      public lastClipboardText: string | null = null;
      public clipboardHistory: string[] = [];

      constructor(defaultSettings: UserSettings) {
        this.userSettingsByUser.default = defaultSettings;
        Object.defineProperty(global, 'navigator', {
          value: {
            clipboard: {
              writeText: jest.fn(async (text: string) => {
                this.lastClipboardText = text;
                this.clipboardHistory.push(text);
              }),
            },
          },
          configurable: true,
          writable: true,
        });
        (getSystemStaticInfo as jest.Mock).mockImplementation((id?: string | number) => {
          if (id == null) return undefined;
          const sys = this.systems.find(
            s => s.id === id.toString() || s.system_static_info?.solar_system_id?.toString() === id.toString(),
          );
          return sys?.system_static_info;
        });
      }

      public setUserSettings(user: string, settings: UserSettings) {
        this.userSettingsByUser[user] = settings;
      }

      public addSystem(
        id: string,
        systemClass: number,
        name: string = id,
        overrides: Partial<SolarSystemRawType> = {},
      ): SolarSystemRawType {
        const numericId = parseInt(id.replace(/\D/g, ''), 10) || this.systems.length + 31000001;
        const sys = createMockSystem({
          id,
          name,
          system_static_info: {
            ...createMockSystem({ id }).system_static_info,
            solar_system_id: numericId,
            solar_system_name: name,
            solar_system_name_lc: name.toLowerCase(),
            system_class: systemClass,
          },
          ...overrides,
        });
        this.systems.push(sys);
        if (!this.systemSignatures[id]) {
          this.systemSignatures[id] = [];
        }
        return sys;
      }

      public getSystem(id: string): SolarSystemRawType {
        const sys = this.systems.find(
          s => s.id === id || s.system_static_info?.solar_system_id?.toString() === id.toString(),
        );
        if (!sys) throw new Error(`System ${id} not found`);
        return sys;
      }

      public getSignature(systemId: string, eveId: string): SystemSignature {
        const sig = (this.systemSignatures[systemId] || []).find(s => s.eve_id === eveId);
        if (!sig) throw new Error(`Signature ${eveId} not found in ${systemId}`);
        return sig;
      }

      public createOutCommand(user: string = this.activeUser): OutCommandHandler {
        return (async (event: { type: OutCommand; data: unknown }) => {
          this.commandLog.push({ user, type: event.type, data: event.data });
          const { type } = event;
          const data = (event.data || {}) as Record<string, unknown>;

          switch (type) {
            case OutCommand.getUserSettings:
              return { user_settings: this.userSettingsByUser[user] ?? this.userSettingsByUser.default };

            case OutCommand.updateSignatures: {
              const sysId = String(data.system_id);
              const current = [...(this.systemSignatures[sysId] || [])];
              const added = (data.added as SystemSignature[]) || [];
              const updated = (data.updated as SystemSignature[]) || [];
              const removed = (data.removed as SystemSignature[]) || [];

              for (const sig of added) {
                const idx = current.findIndex(s => s.eve_id === sig.eve_id);
                if (idx >= 0) current[idx] = { ...current[idx], ...sig };
                else current.push({ ...sig });
              }
              for (const sig of updated) {
                const idx = current.findIndex(s => s.eve_id === sig.eve_id);
                if (idx >= 0) current[idx] = { ...current[idx], ...sig };
                else current.push({ ...sig });
              }
              for (const rem of removed) {
                const idx = current.findIndex(s => s.eve_id === rem.eve_id);
                if (idx >= 0) current[idx] = { ...current[idx], deleted: true };
              }
              this.systemSignatures[sysId] = current;
              return {};
            }

            case OutCommand.unlinkSignature: {
              const sysId = String(data.solar_system_source);
              const eveId = String(data.signature_eve_id);
              const sigs = this.systemSignatures[sysId] || [];
              const sigIdx = sigs.findIndex(s => s.eve_id === eveId);
              if (sigIdx >= 0) {
                const prevLinked = sigs[sigIdx].linked_system;
                if (prevLinked) {
                  const targetSys = this.systems.find(
                    s =>
                      s.id === prevLinked.solar_system_id?.toString() ||
                      s.system_static_info?.solar_system_id === prevLinked.solar_system_id,
                  );
                  if (targetSys && targetSys.linked_sig_eve_id === eveId) {
                    targetSys.linked_sig_eve_id = null;
                    if (targetSys.temporary_name && targetSys.temporary_name === sigs[sigIdx].temporary_name) {
                      targetSys.temporary_name = null;
                    }
                  }
                }
                const copy = { ...sigs[sigIdx] };
                delete copy.linked_system;
                sigs[sigIdx] = copy;
              }
              return {};
            }

            case OutCommand.linkSignatureToSystem: {
              const sourceId = String(data.solar_system_source);
              const targetId = String(data.solar_system_target);
              const eveId = String(data.signature_eve_id);

              const sourceSys = this.getSystem(sourceId);
              const targetSys = this.getSystem(targetId);
              const sigs = this.systemSignatures[sourceSys.id] || [];
              const sigIdx = sigs.findIndex(s => s.eve_id === eveId);
              if (sigIdx < 0) return {};

              const sig = sigs[sigIdx];

              // If previously linked to a different system, clear old target's linked_sig_eve_id
              if (
                sig.linked_system &&
                sig.linked_system.solar_system_id !== targetSys.system_static_info.solar_system_id
              ) {
                const oldTarget = this.systems.find(
                  s => s.system_static_info.solar_system_id === sig.linked_system?.solar_system_id,
                );
                if (oldTarget && oldTarget.linked_sig_eve_id === eveId) {
                  oldTarget.linked_sig_eve_id = null;
                }
              }

              sigs[sigIdx] = {
                ...sig,
                group: SignatureGroup.Wormhole,
                linked_system: targetSys.system_static_info,
              };

              // Ensure connection exists
              const hasConn = this.connections.some(
                c =>
                  (c.source === sourceSys.id && c.target === targetSys.id) ||
                  (c.source === targetSys.id && c.target === sourceSys.id),
              );
              if (!hasConn) {
                this.connections.push(
                  createMockConnection({
                    id: `${sourceSys.id}_${targetSys.id}`,
                    source: sourceSys.id,
                    target: targetSys.id,
                    type: 0,
                  }),
                );
              }

              // Mirror backend forward_sig and has_active_linked_sig? check
              const targetSigs = this.systemSignatures[targetSys.id] || [];
              const forwardSig = targetSigs.find(
                s =>
                  !s.deleted &&
                  (s.linked_system?.solar_system_id === sourceSys.system_static_info.solar_system_id ||
                    s.linked_system?.solar_system_id?.toString() === sourceSys.id),
              );

              const hasActiveLinkedSig =
                targetSys.linked_sig_eve_id != null &&
                Object.values(this.systemSignatures)
                  .flat()
                  .some(
                    s =>
                      !s.deleted &&
                      s.eve_id === targetSys.linked_sig_eve_id &&
                      (s.linked_system?.solar_system_id === targetSys.system_static_info.solar_system_id ||
                        s.linked_system?.solar_system_id?.toString() === targetSys.id),
                  );

              const sigCustomInfo = sigs[sigIdx].custom_info ? JSON.parse(sigs[sigIdx].custom_info!) : {};
              const isReturnSig =
                sigs[sigIdx].temporary_name === '<' ||
                (sigCustomInfo.bookmark_index === undefined &&
                  (typeof sigCustomInfo.bookmark_index_chained === 'string' ||
                    typeof sigCustomInfo.bookmark_index_chained_letters === 'string'));

              const wasAlreadyLinkedToSig = targetSys.linked_sig_eve_id === eveId;
              if (!isReturnSig && (wasAlreadyLinkedToSig || (!forwardSig && !hasActiveLinkedSig))) {
                targetSys.linked_sig_eve_id = eveId;
                if (sigs[sigIdx].temporary_name) {
                  targetSys.temporary_name = sigs[sigIdx].temporary_name || null;
                } else if (wasAlreadyLinkedToSig) {
                  targetSys.temporary_name = null;
                } else {
                  this.syncSystemToLinkedSignature(targetSys);
                }
              }

              return {};
            }

            case OutCommand.updateSystemTag: {
              const sys = this.getSystem(String(data.system_id));
              const oldTag = sys.tag;
              const newTag = (data.value as string) || null;
              sys.tag = newTag;
              if (oldTag !== newTag) {
                this.syncSystemToLinkedSignature(sys, { tagChanged: true });
              }
              return {};
            }

            case OutCommand.updateSystemLabels: {
              const sys = this.getSystem(String(data.system_id));
              const oldCustomLabel = sys.labels ? new LabelsManager(sys.labels).customLabel?.trim() || null : null;
              sys.labels = (data.value as string) || null;
              const newCustomLabel = sys.labels ? new LabelsManager(sys.labels).customLabel?.trim() || null : null;
              if (oldCustomLabel !== newCustomLabel) {
                this.syncSystemToLinkedSignature(sys, { labelsChanged: true });
              }
              return {};
            }

            case OutCommand.updateSystemTemporaryName: {
              const sys = this.getSystem(String(data.system_id));
              const oldTemp = sys.temporary_name;
              const newTemp = (data.value as string) || null;
              sys.temporary_name = newTemp;
              if (oldTemp !== newTemp) {
                this.syncSystemToLinkedSignature(sys, { tempNameChanged: true });
              }
              return {};
            }

            default:
              return {};
          }
        }) as OutCommandHandler;
      }

      /**
       * Mirrors WandererApp.Map.Server.SystemsImpl.maybe_sync_to_signatures/4
       */
      private syncSystemToLinkedSignature(
        sys: SolarSystemRawType,
        opts: { tagChanged?: boolean; labelsChanged?: boolean; tempNameChanged?: boolean } = {},
      ) {
        const tag = sys.tag && sys.tag.trim() !== '' ? sys.tag.trim() : null;
        const customLabel = sys.labels ? new LabelsManager(sys.labels).customLabel?.trim() || null : null;
        const tempName = sys.temporary_name && sys.temporary_name.trim() !== '' ? sys.temporary_name.trim() : null;

        let effectiveName: string | null = null;
        if (opts.tempNameChanged) {
          effectiveName = tempName || customLabel || tag;
        } else if (opts.labelsChanged) {
          effectiveName = customLabel || tag;
        } else if (opts.tagChanged) {
          effectiveName = tag || customLabel;
        } else {
          effectiveName = customLabel || tag || tempName;
        }

        for (const [sourceSysId, sigs] of Object.entries(this.systemSignatures)) {
          const sourceSys = this.getSystem(sourceSysId);
          for (let i = 0; i < sigs.length; i++) {
            const sig = sigs[i];
            if (sig.deleted) continue;
            const isLinkedToSys =
              sig.linked_system?.solar_system_id === sys.system_static_info.solar_system_id ||
              sig.linked_system?.solar_system_id?.toString() === sys.id;
            if (!isLinkedToSys) continue;

            const sigInfo = sig.custom_info ? JSON.parse(sig.custom_info) : {};
            const isMarkedReturn =
              sig.temporary_name === '<' ||
              (sigInfo.bookmark_index === undefined &&
                (typeof sigInfo.bookmark_index_chained === 'string' ||
                  typeof sigInfo.bookmark_index_chained_letters === 'string'));

            const isReturnSig =
              !sys.linked_sig_eve_id &&
              (isMarkedReturn ||
                (this.systemSignatures[sys.id] || []).some(
                  s =>
                    !s.deleted &&
                    (s.linked_system?.solar_system_id === sourceSys.system_static_info.solar_system_id ||
                      s.linked_system?.solar_system_id?.toString() === sourceSys.id),
                ));

            if ((sys.linked_sig_eve_id === sig.eve_id || !sys.linked_sig_eve_id) && !isReturnSig) {
              sigs[i] = { ...sig, temporary_name: effectiveName ?? undefined };
            }
          }
        }
      }

      public async pasteClipboard(user: string, systemId: string, clipboardText: string) {
        const parsed = parseSignatures(clipboardText, [SignatureKind.CosmicSignature, SignatureKind.CosmicAnomaly]);
        const outCommand = this.createOutCommand(user);
        await outCommand({
          type: OutCommand.updateSignatures,
          data: {
            system_id: systemId,
            added: parsed,
            updated: [],
            removed: [],
            deleteTimeout: 0,
          },
        });
      }

      public async editSignature(
        user: string,
        systemId: string,
        eveId: string,
        formValues: SignatureSettingsFormValues,
      ) {
        const sig = this.getSignature(systemId, eveId);
        const outCommand = this.createOutCommand(user);
        return executeSaveSignatureSettings({
          signatureData: sig,
          formValues: {
            group: sig.group,
            type: sig.type,
            description: sig.description,
            temporary_name: sig.temporary_name,
            linked_system: sig.linked_system?.solar_system_id?.toString() ?? undefined,
            ...formValues,
          },
          systemId,
          userSettings: this.userSettingsByUser[user] ?? this.userSettingsByUser.default,
          systemSignatures: this.systemSignatures,
          systems: this.systems,
          wormholesData: this.wormholesData,
          connections: this.connections,
          outCommand,
        });
      }

      public async splashAndLink(
        user: string,
        sourceId: string,
        targetId: string,
        eveId: string,
        targetClassGroup: string | null = null,
      ) {
        const sourceSys = this.getSystem(sourceId);
        const targetSys = this.getSystem(targetId);
        const hasConn = this.connections.some(
          c =>
            (c.source === sourceSys.id && c.target === targetSys.id) ||
            (c.source === targetSys.id && c.target === sourceSys.id),
        );
        if (!hasConn) {
          this.connections.push(
            createMockConnection({
              id: `${sourceSys.id}_${targetSys.id}`,
              source: sourceSys.id,
              target: targetSys.id,
              type: 0,
            }),
          );
        }

        const sig = this.getSignature(sourceId, eveId);
        const outCommand = this.createOutCommand(user);
        return executeLinkSignatureToSystem({
          signature: sig,
          data: {
            solar_system_source: Number(sourceId) || (sourceId as unknown as number),
            solar_system_target: Number(targetId) || (targetId as unknown as number),
          },
          targetSystemClassGroup: targetClassGroup,
          userSettings: this.userSettingsByUser[user] ?? this.userSettingsByUser.default,
          systemSignatures: this.systemSignatures,
          systems: this.systems,
          wormholesData: this.wormholesData,
          connections: this.connections,
          outCommand,
        });
      }

      public async manualConnect(user: string, sourceId: string, targetId: string, connectionType: number = 0) {
        this.connections.push(
          createMockConnection({
            id: `${sourceId}_${targetId}`,
            source: sourceId,
            target: targetId,
            type: connectionType,
          }),
        );
        const outCommand = this.createOutCommand(user);
        await executeManualConnectionAutoTag({
          source: sourceId,
          target: targetId,
          addConnPromise: Promise.resolve({ connection_type: connectionType }),
          outCommand,
          getMapState: () => ({
            systems: this.systems,
            connections: this.connections,
            systemSignatures: this.systemSignatures,
          }),
        });
      }

      public async renameSystemTag(user: string, systemId: string, newTag: string | null) {
        const outCommand = this.createOutCommand(user);
        await outCommand({
          type: OutCommand.updateSystemTag,
          data: { system_id: systemId, value: newTag },
        });
      }

      /**
       * Simulates an ESI character-tracking splash from sourceId to targetId where
       * the backend adds the connection automatically and NO signatures are pasted.
       */
      public esiSplashWithoutPasting(sourceId: string, targetId: string, connectionType: number = 0) {
        const hasConn = this.connections.some(
          c => (c.source === sourceId && c.target === targetId) || (c.source === targetId && c.target === sourceId),
        );
        if (!hasConn) {
          this.connections.push(
            createMockConnection({
              id: `${sourceId}_${targetId}`,
              source: sourceId,
              target: targetId,
              type: connectionType,
            }),
          );
        }
      }

      /**
       * Simulates SystemSettingsDialog handleSave, which sends updateSystemLabels
       * followed immediately by updateSystemTemporaryName.
       */
      public async renameSystemViaSettingsDialog(
        user: string,
        systemId: string,
        opts: { customLabel?: string; temporaryName?: string; statusLabels?: string[] },
      ) {
        const sys = this.getSystem(systemId);
        const lm = new LabelsManager(sys.labels || '');
        if (opts.customLabel !== undefined) {
          lm.updateCustomLabel(opts.customLabel);
        }
        if (opts.statusLabels) {
          for (const lbl of opts.statusLabels) {
            if (!lm.hasLabel(lbl)) lm.toggleLabel(lbl);
          }
        }
        const outCommand = this.createOutCommand(user);
        await outCommand({
          type: OutCommand.updateSystemLabels,
          data: {
            system_id: systemId,
            value: lm.toString(),
          },
        });
        await outCommand({
          type: OutCommand.updateSystemTemporaryName,
          data: {
            system_id: systemId,
            value: opts.temporaryName !== undefined ? opts.temporaryName : sys.temporary_name,
          },
        });
      }

      /**
       * Simulates rolling/closing a wormhole branch: removes the connection between
       * parentId and childId and marks the signature in parentId as deleted.
       */
      public async rollBranch(user: string, parentId: string, childId: string, sigEveId?: string) {
        this.connections = this.connections.filter(
          c => !((c.source === parentId && c.target === childId) || (c.source === childId && c.target === parentId)),
        );
        if (sigEveId) {
          const sig = this.getSignature(parentId, sigEveId);
          await this.createOutCommand(user)({
            type: OutCommand.updateSignatures,
            data: {
              system_id: parentId,
              added: [],
              updated: [],
              removed: [sig],
              deleteTimeout: 0,
            },
          });
        }
      }
    }

    it('handles multi-user interleaved scanning across 3 parallel chains, return holes, stargates, re-linking, renaming, and rolled-hole gap filling', async () => {
      const sharedSettings: UserSettings = {
        bookmark_name_format: '{chain_index} {dest_type} - {sig_letters}',
        bookmark_auto_temp_name: 'chain_index',
        system_auto_tag: 'chain_index',
        system_custom_label_name: null,
        bookmark_return_hole_ignore: true,
        bookmark_return_hole_symbol: '<',
        bookmark_wormholes_start_at_zero: false,
        link_signature_on_splash: true,
        bookmark_custom_mapping: {
          chain_separator: '.',
        },
      };

      const sim = new MapWorkflowSimulator(sharedSettings);
      sim.setUserSettings('alice', sharedSettings);
      sim.setUserSettings('bob', sharedSettings);

      // 1. Seed systems for 3 parallel chains + a highsec stargate neighbor
      sim.addSystem('31000001', 2, 'Home');
      sim.addSystem('31000101', 3, 'Chain1_Hop1_C3');
      sim.addSystem('31000102', 4, 'Chain1_Hop2a_C4');
      sim.addSystem('31000103', 4, 'Chain1_Hop2b_C4');
      sim.addSystem('31000104', 7, 'Chain1_Hop3_HS');
      sim.addSystem('30000142', 7, 'Jita_Stargate_Neighbor');
      sim.addSystem('31000201', 5, 'Chain2_Hop1_C5');
      sim.addSystem('31000202', 5, 'Chain2_Hop2_C5');
      sim.addSystem('31000301', 3, 'Chain3_Manual_C3');

      // 2. Alice pastes probe scanner signatures in Home
      await sim.pasteClipboard(
        'alice',
        '31000001',
        [
          'AAA-111\tCosmic Signature\tWormhole\tUnstable Wormhole\t100.0%\t1.00 AU',
          'BBB-222\tCosmic Signature\tWormhole\tUnstable Wormhole\t100.0%\t2.00 AU',
        ].join('\n'),
      );

      // Alice sets AAA-111 as leading to C3 (C247) before jumping
      await sim.editSignature('alice', '31000001', 'AAA-111', {
        group: SignatureGroup.Wormhole,
        type: 'C247',
        destType: 'c3',
      });
      expect(sim.getSignature('31000001', 'AAA-111').temporary_name).toBe('1');
      expect(sim.lastClipboardText).toBe('1 C3 - AAA');

      // Bob simultaneously sets BBB-222 in Home as leading to C5 (H296)
      await sim.editSignature('bob', '31000001', 'BBB-222', {
        group: SignatureGroup.Wormhole,
        type: 'H296',
        destType: 'c5',
      });
      expect(sim.getSignature('31000001', 'BBB-222').temporary_name).toBe('2');
      expect(sim.lastClipboardText).toBe('2 C5 - BBB');

      // 3. Alice splashes into Chain1_Hop1_C3 and links AAA-111; Bob splashes into Chain2_Hop1_C5 and links BBB-222
      await sim.splashAndLink('alice', '31000001', '31000101', 'AAA-111', 'C3');
      await sim.splashAndLink('bob', '31000001', '31000201', 'BBB-222', 'C5');

      expect(sim.getSystem('31000101').tag).toBe('1');
      expect(sim.getSystem('31000101').temporary_name).toBe('1');
      expect(sim.getSystem('31000101').linked_sig_eve_id).toBe('AAA-111');

      expect(sim.getSystem('31000201').tag).toBe('2');
      expect(sim.getSystem('31000201').temporary_name).toBe('2');
      expect(sim.getSystem('31000201').linked_sig_eve_id).toBe('BBB-222');

      // 4. Interleaved scanning inside Chain 1 and Chain 2
      // Alice scans Chain1_Hop1_C3: return hole RET-101 + two forward holes FWD-102, FWD-103
      await sim.pasteClipboard(
        'alice',
        '31000101',
        [
          'RET-101\tCosmic Signature\tWormhole\tUnstable Wormhole\t100.0%\t1.00 AU',
          'FWD-102\tCosmic Signature\tWormhole\tUnstable Wormhole\t100.0%\t2.00 AU',
          'FWD-103\tCosmic Signature\tWormhole\tUnstable Wormhole\t100.0%\t3.00 AU',
        ].join('\n'),
      );

      // Alice links RET-101 back to Home: should be marked '<', not overwrite Home's tag, and not consume index 1.1!
      await sim.editSignature('alice', '31000101', 'RET-101', {
        group: SignatureGroup.Wormhole,
        type: 'K162',
        linked_system: '31000001',
      });
      expect(sim.getSignature('31000101', 'RET-101').temporary_name).toBe('<');
      expect(sim.getSystem('31000001').tag).toBeNull();
      expect(sim.getSystem('31000001').linked_sig_eve_id).toBeNull();

      // Alice links FWD-102 -> Chain1_Hop2a_C4 (gets 1.1) and FWD-103 -> Chain1_Hop2b_C4 (gets 1.2)
      await sim.splashAndLink('alice', '31000101', '31000102', 'FWD-102', 'C4');
      expect(sim.getSystem('31000102').tag).toBe('1.1');
      expect(sim.lastClipboardText).toBe('1.1 C4 - FWD');
      await sim.splashAndLink('alice', '31000101', '31000103', 'FWD-103', 'C4');
      expect(sim.getSystem('31000103').tag).toBe('1.2');
      expect(sim.lastClipboardText).toBe('1.2 C4 - FWD');

      // Meanwhile Bob scans Chain2_Hop1_C5: return hole RET-201 + forward hole FWD-202
      await sim.pasteClipboard(
        'bob',
        '31000201',
        [
          'RET-201\tCosmic Signature\tWormhole\tUnstable Wormhole\t100.0%\t1.00 AU',
          'FWD-202\tCosmic Signature\tWormhole\tUnstable Wormhole\t100.0%\t2.00 AU',
        ].join('\n'),
      );
      await sim.splashAndLink('bob', '31000201', '31000001', 'RET-201', 'C2');
      await sim.splashAndLink('bob', '31000201', '31000202', 'FWD-202', 'C5');
      expect(sim.getSignature('31000201', 'RET-201').temporary_name).toBe('<');
      expect(sim.getSystem('31000202').tag).toBe('2.1');

      // 5. Depth 3 in Chain 1 + Stargate jump:
      // Alice scans Chain1_Hop2a_C4 ('1.1'): links return hole RET-110 back to Chain1_Hop1_C3 ('1') and forward hole FWD-111 to Chain1_Hop3_HS ('1.1.1')
      await sim.pasteClipboard(
        'alice',
        '31000102',
        [
          'RET-110\tCosmic Signature\tWormhole\tUnstable Wormhole\t100.0%\t1.00 AU',
          'FWD-111\tCosmic Signature\tWormhole\tUnstable Wormhole\t100.0%\t2.00 AU',
        ].join('\n'),
      );
      await sim.splashAndLink('alice', '31000102', '31000101', 'RET-110', 'C3');
      expect(sim.getSignature('31000102', 'RET-110').temporary_name).toBe('<');
      // Chain1_Hop1_C3 must keep its forward linked_sig_eve_id ('AAA-111') and tag ('1')!
      expect(sim.getSystem('31000101').linked_sig_eve_id).toBe('AAA-111');
      expect(sim.getSystem('31000101').tag).toBe('1');

      await sim.splashAndLink('alice', '31000102', '31000104', 'FWD-111', 'HS');
      expect(sim.getSystem('31000104').tag).toBe('1.1.1');
      expect(sim.lastClipboardText).toBe('1.1.1 HS - FWD');

      // Alice jumps a stargate (connection_type: 1) from Chain1_Hop3_HS to Jita_Stargate_Neighbor -> must NOT auto-tag!
      await sim.manualConnect('alice', '31000104', '30000142', 1);
      expect(sim.getSystem('30000142').tag).toBeNull();

      // 6. Manual wormhole splash (Chain 3) from Home (all Home wormholes are already linked):
      await sim.manualConnect('bob', '31000001', '31000301', 0);
      expect(sim.getSystem('31000301').tag).toBe('3');

      // 7. Re-linking mistake recovery:
      // Suppose Bob accidentally linked a new sig ERR-203 in Chain2_Hop1_C5 back to Home ('<'), then fixes it in SignatureSettings to point to a new C4 system
      const c2Hop2b = sim.addSystem('31000203', 4, 'Chain2_Hop2b_C4');
      await sim.pasteClipboard(
        'bob',
        '31000201',
        'ERR-203\tCosmic Signature\tWormhole\tUnstable Wormhole\t100.0%\t1.00 AU',
      );
      await sim.editSignature('bob', '31000201', 'ERR-203', {
        group: SignatureGroup.Wormhole,
        type: 'K162',
        linked_system: '31000001',
      });
      expect(sim.getSignature('31000201', 'ERR-203').temporary_name).toBe('<');

      // Bob fixes ERR-203 in SignatureSettings: changes linked_system from Home ('31000001') to Chain2_Hop2b_C4 ('31000203')
      await sim.editSignature('bob', '31000201', 'ERR-203', {
        group: SignatureGroup.Wormhole,
        type: 'X877',
        destType: 'c4',
        linked_system: c2Hop2b.id,
      });
      expect(sim.getSignature('31000201', 'ERR-203').temporary_name).toBe('2.2');
      expect(sim.getSystem('31000203').tag).toBe('2.2');
      expect(sim.getSystem('31000203').linked_sig_eve_id).toBe('ERR-203');

      // 8. Mid-chain rename & downstream propagation:
      // FC renames Chain2_Hop1_C5 from tag '2' to '5'
      await sim.renameSystemTag('bob', '31000201', '5');
      // Forward signature BBB-222 in Home automatically syncs its temporary_name to '5', while return hole RET-201 stays '<'!
      expect(sim.getSignature('31000001', 'BBB-222').temporary_name).toBe('5');
      expect(sim.getSignature('31000201', 'RET-201').temporary_name).toBe('<');

      // Next hole scanned in Chain2_Hop1_C5 chains off the new tag '5' (indices 1 and 2 are used by FWD-202 and ERR-203, so next is 5.3)
      await sim.pasteClipboard(
        'bob',
        '31000201',
        'NEW-204\tCosmic Signature\tWormhole\tUnstable Wormhole\t100.0%\t1.00 AU',
      );
      await sim.editSignature('bob', '31000201', 'NEW-204', {
        group: SignatureGroup.Wormhole,
        type: 'H296',
        destType: 'c5',
      });
      expect(sim.getSignature('31000201', 'NEW-204').temporary_name).toBe('5.3');

      // 9. Rolled wormhole & gap filling:
      // FWD-102 ('1.1') in Chain1_Hop1_C3 rolls and is deleted, and Chain1_Hop2a_C4 is untagged/removed
      await sim.createOutCommand('alice')({
        type: OutCommand.updateSignatures,
        data: {
          system_id: '31000101',
          added: [],
          updated: [],
          removed: [sim.getSignature('31000101', 'FWD-102')],
          deleteTimeout: 0,
        },
      });
      sim.getSystem('31000102').tag = null;
      sim.getSystem('31000102').temporary_name = null;

      // Alice scans a new replacement static in Chain1_Hop1_C3 -> reuses gap '1.1' instead of '1.3'!
      await sim.pasteClipboard(
        'alice',
        '31000101',
        'REP-105\tCosmic Signature\tWormhole\tUnstable Wormhole\t100.0%\t1.00 AU',
      );
      await sim.editSignature('alice', '31000101', 'REP-105', {
        group: SignatureGroup.Wormhole,
        type: 'X877',
        destType: 'c4',
      });
      expect(sim.getSignature('31000101', 'REP-105').temporary_name).toBe('1.1');
    });

    it('handles single-hop system auto-tagging (index) across multiple branches without cross-branch collisions', async () => {
      const singleHopSettings: UserSettings = {
        bookmark_name_format: '{chain_index} {dest_type}',
        bookmark_auto_temp_name: 'index',
        system_auto_tag: 'index',
        bookmark_return_hole_ignore: true,
        bookmark_return_hole_symbol: '<',
        bookmark_wormholes_start_at_zero: false,
        bookmark_custom_mapping: {
          chain_separator: '.',
        },
      };

      const sim = new MapWorkflowSimulator(singleHopSettings);
      sim.addSystem('31000001', 2, 'Home');
      sim.addSystem('31000101', 3, 'Hop1');
      sim.addSystem('31000102', 4, 'Hop2a');
      sim.addSystem('31000103', 4, 'Hop2b');
      sim.addSystem('31000104', 5, 'Hop3');
      sim.addSystem('31000201', 3, 'Home_Second_Branch');

      // Connect Home -> Hop1 via sig HAA-222 (Suppose HAA-222 was index 2 because index 1 rolled earlier)
      await sim.pasteClipboard(
        'default',
        '31000001',
        [
          'OLD-111\tCosmic Signature\tWormhole\tUnstable Wormhole\t100.0%\t1.00 AU',
          'HAA-222\tCosmic Signature\tWormhole\tUnstable Wormhole\t100.0%\t1.00 AU',
        ].join('\n'),
      );
      await sim.editSignature('default', '31000001', 'OLD-111', {
        group: SignatureGroup.Wormhole,
        type: 'C247',
        destType: 'c3',
      });
      await sim.splashAndLink('default', '31000001', '31000101', 'HAA-222', 'C3');
      expect(sim.getSystem('31000101').tag).toBe('2');

      // In Hop1 (tag '2'), manually connect Hop2a and Hop2b:
      // Hop2a gets single-hop tag '1', Hop2b must detect Hop2a's single-hop tag '1' and get '2'!
      await sim.manualConnect('default', '31000101', '31000102', 0);
      await sim.manualConnect('default', '31000101', '31000103', 0);
      expect(sim.getSystem('31000102').tag).toBe('1');
      expect(sim.getSystem('31000103').tag).toBe('2');

      // In Hop2a (child 1 of Hop1 '2'), scan and link a wormhole to Hop3:
      // Even though Hop2a has single-hop tag '1', its full chain path is '2.1', so Hop3's bookmark is '2.1.1 C5' and Hop3's single-hop tag is '1'!
      await sim.pasteClipboard(
        'default',
        '31000102',
        'DEP-333\tCosmic Signature\tWormhole\tUnstable Wormhole\t100.0%\t1.00 AU',
      );
      await sim.splashAndLink('default', '31000102', '31000104', 'DEP-333', 'C5');
      expect(sim.lastClipboardText).toBe('2.1.1 C5');
      expect(sim.getSystem('31000104').tag).toBe('1');

      // Now OLD-111 in Home expires/rolls, freeing index 1 in Home.
      // Even though Hop2a and Hop3 (2 and 3 hops away) have single-hop tag '1', Home's new signature must still get index 1!
      await sim.createOutCommand('default')({
        type: OutCommand.updateSignatures,
        data: {
          system_id: '31000001',
          added: [],
          updated: [],
          removed: [sim.getSignature('31000001', 'OLD-111')],
          deleteTimeout: 0,
        },
      });
      await sim.pasteClipboard(
        'default',
        '31000001',
        'NEW-444\tCosmic Signature\tWormhole\tUnstable Wormhole\t100.0%\t1.00 AU',
      );
      await sim.splashAndLink('default', '31000001', '31000201', 'NEW-444', 'C3');
      expect(sim.getSystem('31000201').tag).toBe('1');
    });

    it('handles mixed user preferences (letter chains vs numeric chains), re-linking a forward hole to a different system, and cyclic loop connections without infinite recursion', async () => {
      const letterSettings: UserSettings = {
        bookmark_name_format: '[{chain_index_letters}] {dest_type} - {sig_letters}',
        bookmark_auto_temp_name: 'chain_index_letters',
        system_auto_tag: 'chain_index_letters',
        bookmark_return_hole_ignore: true,
        bookmark_return_hole_symbol: '<',
        bookmark_wormholes_start_at_zero: false,
        bookmark_custom_mapping: { chain_separator: '.' },
      };

      const numericSettings: UserSettings = {
        bookmark_name_format: '[{chain_index}] {dest_type} - {sig_letters}',
        bookmark_auto_temp_name: 'chain_index',
        system_auto_tag: 'chain_index',
        bookmark_return_hole_ignore: true,
        bookmark_return_hole_symbol: '<',
        bookmark_wormholes_start_at_zero: false,
        bookmark_custom_mapping: { chain_separator: '.' },
      };

      const sim = new MapWorkflowSimulator(letterSettings);
      sim.setUserSettings('letter_user', letterSettings);
      sim.setUserSettings('numeric_user', numericSettings);

      sim.addSystem('31000001', 2, 'Home');
      sim.addSystem('31000101', 3, 'BranchA_Wrong');
      sim.addSystem('31000102', 3, 'BranchA_Right');
      sim.addSystem('31000103', 4, 'BranchA_Hop2');
      sim.addSystem('31000201', 5, 'BranchB_Hop1');

      // 1. letter_user pastes sigs in Home and links SIG-AAA to BranchA_Wrong ('A')
      await sim.pasteClipboard(
        'letter_user',
        '31000001',
        [
          'SIG-111\tCosmic Signature\tWormhole\tUnstable Wormhole\t100.0%\t1.00 AU',
          'SIG-222\tCosmic Signature\tWormhole\tUnstable Wormhole\t100.0%\t2.00 AU',
        ].join('\n'),
      );
      await sim.splashAndLink('letter_user', '31000001', '31000101', 'SIG-111', 'C3');
      expect(sim.getSystem('31000101').tag).toBe('A');
      expect(sim.getSystem('31000101').linked_sig_eve_id).toBe('SIG-111');
      expect(sim.lastClipboardText).toBe('[A] C3 - SIG');

      // 2. letter_user realizes SIG-111 actually leads to BranchA_Right ('31000102'), NOT BranchA_Wrong ('31000101'),
      // and updates Leads To in SignatureSettings:
      await sim.editSignature('letter_user', '31000001', 'SIG-111', {
        group: SignatureGroup.Wormhole,
        type: 'C247',
        destType: 'c3',
        linked_system: '31000102',
      });
      // BranchA_Wrong must have its linked_sig_eve_id cleared via OutCommand.unlinkSignature!
      expect(sim.getSystem('31000101').linked_sig_eve_id).toBeNull();
      expect(sim.getSystem('31000102').linked_sig_eve_id).toBe('SIG-111');
      expect(sim.getSystem('31000102').tag).toBe('A');

      // 3. numeric_user links SIG-222 in Home to BranchB_Hop1 -> must detect 'A' is index 1 and assign '2' to BranchB_Hop1!
      await sim.splashAndLink('numeric_user', '31000001', '31000201', 'SIG-222', 'C5');
      expect(sim.getSystem('31000201').tag).toBe('2');
      expect(sim.lastClipboardText).toBe('[2] C5 - SIG');

      // 4. Inside BranchA_Right (tagged 'A' by letter_user), numeric_user scans and links a child hole to BranchA_Hop2:
      // Even though BranchA_Right is tagged 'A', numeric_user's `{chain_index}` must resolve the numeric chain '1.1'!
      await sim.pasteClipboard(
        'numeric_user',
        '31000102',
        'SUB-333\tCosmic Signature\tWormhole\tUnstable Wormhole\t100.0%\t1.00 AU',
      );
      await sim.splashAndLink('numeric_user', '31000102', '31000103', 'SUB-333', 'C4');
      expect(sim.getSystem('31000103').tag).toBe('1.1');
      expect(sim.lastClipboardText).toBe('[1.1] C4 - SUB');

      // 5. Create a wormhole loop/cycle between BranchA_Hop2 and BranchB_Hop1 and scan a new hole in BranchA_Hop2:
      // Must not infinitely recurse on the cycle and must chain cleanly as 1.1.1 / A.1.1!
      sim.connections.push(
        createMockConnection({
          id: 'loop_conn',
          source: '31000201',
          target: '31000103',
          type: 0,
        }),
      );
      await sim.pasteClipboard(
        'letter_user',
        '31000103',
        'LOP-444\tCosmic Signature\tWormhole\tUnstable Wormhole\t100.0%\t1.00 AU',
      );
      await sim.editSignature('letter_user', '31000103', 'LOP-444', {
        group: SignatureGroup.Wormhole,
        type: 'X877',
        destType: 'c4',
      });
      expect(sim.getSignature('31000103', 'LOP-444').temporary_name).toBe('A.1.1');
      expect(sim.lastClipboardText).toBe('[A.1.1] C4 - LOP');
    });

    it('handles pure no-paste exploration (manual connections and untagged ESI splashes across multiple branches) and renaming systems mid-chain', async () => {
      const settings: UserSettings = {
        bookmark_name_format: '{chain_index} {dest_type}',
        bookmark_auto_temp_name: 'chain_index',
        system_auto_tag: 'chain_index',
        system_custom_label_name: null,
        bookmark_return_hole_ignore: true,
        bookmark_return_hole_symbol: '<',
        bookmark_wormholes_start_at_zero: false,
        bookmark_custom_mapping: { chain_separator: '.' },
      };

      const sim = new MapWorkflowSimulator(settings);
      sim.addSystem('31000001', 2, 'Home');
      sim.addSystem('31000101', 3, 'Hop1a');
      sim.addSystem('31000102', 4, 'Hop2a');
      sim.addSystem('31000103', 4, 'Hop2b');
      sim.addSystem('31000104', 5, 'Hop3a');
      sim.addSystem('31000105', 5, 'Hop3b');
      sim.addSystem('31000201', 3, 'Hop1b');
      sim.addSystem('31000301', 3, 'Untagged_ESI_1');
      sim.addSystem('31000302', 4, 'Untagged_ESI_2');
      sim.addSystem('31000303', 5, 'Untagged_ESI_3');

      // 1. Players manually connect systems without pasting any signatures anywhere:
      await sim.manualConnect('default', '31000001', '31000101', 0); // Home -> Hop1a ('1')
      await sim.manualConnect('default', '31000001', '31000201', 0); // Home -> Hop1b ('2')
      await sim.manualConnect('default', '31000101', '31000102', 0); // Hop1a -> Hop2a ('1.1')
      await sim.manualConnect('default', '31000101', '31000103', 0); // Hop1a -> Hop2b ('1.2')

      expect(sim.getSystem('31000101').tag).toBe('1');
      expect(sim.getSystem('31000201').tag).toBe('2');
      expect(sim.getSystem('31000102').tag).toBe('1.1');
      expect(sim.getSystem('31000103').tag).toBe('1.2');

      // 2. Rename Hop1a in the middle of the unpasted chain from '1' to '4':
      // Even though Hop2a still has its old auto-tag '1.1', connecting Hop2a -> Hop3a must dynamically resolve
      // Hop1a ('4') -> Hop2a ('4.1') -> Hop3a ('4.1.1')!
      await sim.renameSystemTag('default', '31000101', '4');
      await sim.manualConnect('default', '31000102', '31000104', 0);
      expect(sim.getSystem('31000104').tag).toBe('4.1.1');

      // 3. Directly rename Hop2a via SystemSettingsDialog customLabel to a single-segment override '9':
      // Connecting Hop2a -> Hop3b must use Hop2a's manual override '9' and avoid colliding with sibling Hop3a (1), assigning '9.2' (or '9.1')!
      await sim.renameSystemViaSettingsDialog('default', '31000102', { customLabel: '9' });
      await sim.manualConnect('default', '31000102', '31000105', 0);
      expect(sim.getSystem('31000105').tag).toBe('9.1');

      // 4. Pure untagged ESI splashes (Home -> Untagged_ESI_1 -> Untagged_ESI_2) where NO signatures were pasted
      // and NO auto-tags were applied on the intermediate hops, followed by manualConnect to Untagged_ESI_3:
      sim.esiSplashWithoutPasting('31000001', '31000301');
      sim.esiSplashWithoutPasting('31000301', '31000302');
      expect(sim.getSystem('31000301').tag).toBeNull();
      expect(sim.getSystem('31000302').tag).toBeNull();

      // Home already has children with tags '4' (Hop1a) and '2' (Hop1b), so Untagged_ESI_1 resolves to index 1 ('1'),
      // Untagged_ESI_2 resolves to '1.1', and Untagged_ESI_3 gets '1.1.1'!
      await sim.manualConnect('default', '31000302', '31000303', 0);
      expect(sim.getSystem('31000303').tag).toBe('1.1.1');
    });

    it('handles mixed pasted and unpasted chains, linking return holes back to unpasted parents, and mid-chain renames via Tag and SystemSettingsDialog', async () => {
      const settings: UserSettings = {
        bookmark_name_format: '{chain_index} {dest_type} - {sig_letters}',
        bookmark_auto_temp_name: 'chain_index',
        system_auto_tag: 'chain_index',
        system_custom_label_name: null,
        bookmark_return_hole_ignore: true,
        bookmark_return_hole_symbol: '<',
        bookmark_wormholes_start_at_zero: false,
        bookmark_custom_mapping: { chain_separator: '.' },
      };

      const sim = new MapWorkflowSimulator(settings);
      sim.setUserSettings('scout_a', settings);
      sim.setUserSettings('scout_b', settings);

      sim.addSystem('31000001', 2, 'Home');
      sim.addSystem('31000101', 3, 'Hop1_UnpastedFromHome');
      sim.addSystem('31000102', 4, 'Hop2_PastedFromHop1');
      sim.addSystem('31000103', 5, 'Hop3_UnpastedFromHop2');
      sim.addSystem('31000104', 3, 'Hop4a_PastedFromHop3');
      sim.addSystem('31000105', 4, 'Hop4b_AfterHop1Rename');
      sim.addSystem('31000106', 5, 'Hop4c_AfterHop2DialogRename');

      // ---------------------------------------------------------------------------
      // STEP 1: scout_a jumps from Home -> Hop1 WITHOUT pasting any sigs in Home!
      // In Hop1, scout_a pastes signatures (RET-101 and FWD-102) and links RET-101 back to Home.
      // RET-101 MUST be recognized as the return hole ('<') even though Home has 0 signatures!
      // ---------------------------------------------------------------------------
      sim.esiSplashWithoutPasting('31000001', '31000101');
      await sim.pasteClipboard(
        'scout_a',
        '31000101',
        [
          'RET-101\tCosmic Signature\tWormhole\tUnstable Wormhole\t100.0%\t1.00 AU',
          'FWD-102\tCosmic Signature\tWormhole\tUnstable Wormhole\t100.0%\t2.00 AU',
        ].join('\n'),
      );

      // Even if scout_a first marks RET-101 as a wormhole in SignatureSettings before linking it to Home:
      await sim.editSignature('scout_a', '31000101', 'RET-101', {
        group: SignatureGroup.Wormhole,
        type: 'K162',
        destType: 'c2',
      });
      // And then links RET-101 to Home:
      await sim.splashAndLink('scout_a', '31000101', '31000001', 'RET-101', 'C2');

      const ret101 = sim.getSignature('31000101', 'RET-101');
      expect(ret101.temporary_name).toBe('<');
      expect(JSON.parse(ret101.custom_info!).bookmark_index).toBeUndefined();
      expect(sim.lastClipboardText).toBe('< C2 - RET');
      // Home must NOT be auto-tagged or linked to RET-101!
      expect(sim.getSystem('31000001').tag).toBeNull();
      expect(sim.getSystem('31000001').linked_sig_eve_id).toBeNull();
      expect(sim.getSystem('31000001').temporary_name).toBeNull();

      // ---------------------------------------------------------------------------
      // STEP 2: Still in Hop1, scout_a links FWD-102 forward to Hop2.
      // Because RET-101 was freed as '<', FWD-102 gets index 1 in Hop1 ('1.1')!
      // ---------------------------------------------------------------------------
      await sim.splashAndLink('scout_a', '31000101', '31000102', 'FWD-102', 'C4');
      expect(sim.getSignature('31000101', 'FWD-102').temporary_name).toBe('1.1');
      expect(sim.lastClipboardText).toBe('1.1 C4 - FWD');
      expect(sim.getSystem('31000102').tag).toBe('1.1');
      expect(sim.getSystem('31000102').linked_sig_eve_id).toBe('FWD-102');

      // ---------------------------------------------------------------------------
      // STEP 3: scout_b jumps from Hop2 -> Hop3 WITHOUT pasting any sigs in Hop2!
      // Then in Hop3, scout_b pastes RET-301 and FWD-302, links RET-301 back to Hop2,
      // and links FWD-302 forward to Hop4a.
      // ---------------------------------------------------------------------------
      sim.esiSplashWithoutPasting('31000102', '31000103');
      await sim.pasteClipboard(
        'scout_b',
        '31000103',
        [
          'RET-301\tCosmic Signature\tWormhole\tUnstable Wormhole\t100.0%\t1.00 AU',
          'FWD-302\tCosmic Signature\tWormhole\tUnstable Wormhole\t100.0%\t2.00 AU',
        ].join('\n'),
      );

      // Link RET-301 in Hop3 back to Hop2 (which has 0 signatures pasted!):
      await sim.splashAndLink('scout_b', '31000103', '31000102', 'RET-301', 'C4');
      expect(sim.getSignature('31000103', 'RET-301').temporary_name).toBe('<');
      expect(sim.getSystem('31000102').tag).toBe('1.1');
      expect(sim.getSystem('31000102').linked_sig_eve_id).toBe('FWD-102');

      // Link FWD-302 in Hop3 forward to Hop4a:
      // Hop1 ('1') -> Hop2 ('1.1') -> Hop3 (unpasted child 1 -> '1.1.1') -> Hop4a ('1.1.1.1')!
      await sim.splashAndLink('scout_b', '31000103', '31000104', 'FWD-302', 'C3');
      expect(sim.getSignature('31000103', 'FWD-302').temporary_name).toBe('1.1.1.1');
      expect(sim.lastClipboardText).toBe('1.1.1.1 C3 - FWD');
      expect(sim.getSystem('31000104').tag).toBe('1.1.1.1');

      // ---------------------------------------------------------------------------
      // STEP 4: Rename Hop1 (at the top of the chain) to tag '5'.
      // Even though Hop2 still has tag '1.1' (from FWD-102) and Hop3 is unpasted,
      // scanning a new hole FWD-303 in Hop3 -> Hop4b must propagate '5' -> '5.1' -> '5.1.1' -> '5.1.1.2'!
      // ---------------------------------------------------------------------------
      await sim.renameSystemTag('scout_a', '31000101', '5');
      await sim.pasteClipboard(
        'scout_b',
        '31000103',
        'FWD-303\tCosmic Signature\tWormhole\tUnstable Wormhole\t100.0%\t3.00 AU',
      );
      await sim.splashAndLink('scout_b', '31000103', '31000105', 'FWD-303', 'C4');
      expect(sim.getSignature('31000103', 'FWD-303').temporary_name).toBe('5.1.1.2');
      expect(sim.lastClipboardText).toBe('5.1.1.2 C4 - FWD');
      expect(sim.getSystem('31000105').tag).toBe('5.1.1.2');

      // ---------------------------------------------------------------------------
      // STEP 5: Rename Hop2 (in the middle of the chain) via SystemSettingsDialog to customLabel '7'.
      // SystemSettingsDialog sends updateSystemLabels('7') followed by unchanged updateSystemTemporaryName('1.1').
      // 1) FWD-102 in Hop1 must sync its temporary_name to '7' (not clobbered by '1.1'!).
      // 2) Scanning FWD-304 in Hop3 -> Hop4c must now chain off Hop2's customLabel '7' as '7.1.3'!
      // ---------------------------------------------------------------------------
      await sim.renameSystemViaSettingsDialog('scout_a', '31000102', { customLabel: '7' });
      expect(sim.getSignature('31000101', 'FWD-102').temporary_name).toBe('7');

      await sim.pasteClipboard(
        'scout_b',
        '31000103',
        'FWD-304\tCosmic Signature\tWormhole\tUnstable Wormhole\t100.0%\t4.00 AU',
      );
      await sim.splashAndLink('scout_b', '31000103', '31000106', 'FWD-304', 'C5');
      expect(sim.getSignature('31000103', 'FWD-304').temporary_name).toBe('7.1.3');
      expect(sim.lastClipboardText).toBe('7.1.3 C5 - FWD');
      expect(sim.getSystem('31000106').tag).toBe('7.1.3');
    });

    it('handles {dest_class_index} (a/b/c) across multiple same-class wormholes while excluding return holes of the same class', async () => {
      const settings: UserSettings = {
        bookmark_name_format: '{chain_index} {dest_type}{dest_class_index} - {sig_letters}',
        bookmark_auto_temp_name: 'chain_index',
        system_auto_tag: 'chain_index',
        bookmark_return_hole_ignore: true,
        bookmark_return_hole_symbol: '<',
        bookmark_wormholes_start_at_zero: false,
        bookmark_custom_mapping: { chain_separator: '.' },
      };

      const sim = new MapWorkflowSimulator(settings);
      // Parent is a C3, Hop1 is a C3, and Hop1 has two forward C3 holes (Hop2a and Hop2b):
      sim.addSystem('31000001', 3, 'C3_Home');
      sim.addSystem('31000101', 3, 'C3_Hop1');
      sim.addSystem('31000102', 3, 'C3_Hop2a');
      sim.addSystem('31000103', 3, 'C3_Hop2b');

      // Jump C3_Home -> C3_Hop1 (unpasted in C3_Home), paste return hole AAA-100 + first forward C3 hole BBB-200 in C3_Hop1:
      sim.esiSplashWithoutPasting('31000001', '31000101');
      await sim.pasteClipboard(
        'default',
        '31000101',
        [
          'AAA-100\tCosmic Signature\tWormhole\tUnstable Wormhole\t100.0%\t1.00 AU',
          'BBB-200\tCosmic Signature\tWormhole\tUnstable Wormhole\t100.0%\t2.00 AU',
        ].join('\n'),
      );

      // Link AAA-100 back to C3_Home (return hole to a C3):
      await sim.splashAndLink('default', '31000101', '31000001', 'AAA-100', 'C3');
      expect(sim.lastClipboardText).toBe('< C3 - AAA');

      // Link BBB-200 forward to C3_Hop2a:
      // Because AAA-100 is a return hole ('<'), BBB-200 is the ONLY forward C3 hole in C3_Hop1 so {dest_class_index} must be empty ('C3', NOT 'C3b')!
      await sim.splashAndLink('default', '31000101', '31000102', 'BBB-200', 'C3');
      expect(sim.lastClipboardText).toBe('1.1 C3 - BBB');

      // Now scan a second forward C3 hole CCC-300 in C3_Hop1 -> C3_Hop2b:
      // Now there are 2 forward C3 holes (BBB-200 and CCC-300), so CCC-300 gets 'b' ('C3b') and re-saving BBB-200 gets 'a' ('C3a')!
      await sim.pasteClipboard(
        'default',
        '31000101',
        'CCC-300\tCosmic Signature\tWormhole\tUnstable Wormhole\t100.0%\t3.00 AU',
      );
      await sim.splashAndLink('default', '31000101', '31000103', 'CCC-300', 'C3');
      expect(sim.lastClipboardText).toBe('1.2 C3b - CCC');

      await sim.editSignature('default', '31000101', 'BBB-200', {
        group: SignatureGroup.Wormhole,
        type: 'C247',
        destType: 'c3',
      });
      expect(sim.lastClipboardText).toBe('1.1 C3a - BBB');
    });

    it('handles zero-indexed chains (bookmark_wormholes_start_at_zero) and empty-separator compact chains (chain_separator: "") with mid-chain renames', async () => {
      const zeroCompactSettings: UserSettings = {
        bookmark_name_format: '{chain_index}/{chain_index_letters} {dest_type}',
        bookmark_auto_temp_name: 'chain_index_letters',
        system_auto_tag: 'chain_index_letters',
        bookmark_return_hole_ignore: true,
        bookmark_return_hole_symbol: '<',
        bookmark_wormholes_start_at_zero: true,
        bookmark_custom_mapping: { chain_separator: '' },
      };

      const sim = new MapWorkflowSimulator(zeroCompactSettings);
      sim.addSystem('31000001', 2, 'Home');
      sim.addSystem('31000101', 3, 'Hop0_A');
      sim.addSystem('31000102', 4, 'Hop1_B');
      sim.addSystem('31000103', 5, 'Hop00_A0');
      sim.addSystem('31000104', 5, 'Hop000_A00');

      // 1. In Home, paste 2 signatures: with startAtZero=true, first hole is index 0 ('0'/'A'), second is index 1 ('1'/'B')
      await sim.pasteClipboard(
        'default',
        '31000001',
        [
          'ZRO-000\tCosmic Signature\tWormhole\tUnstable Wormhole\t100.0%\t1.00 AU',
          'ONE-111\tCosmic Signature\tWormhole\tUnstable Wormhole\t100.0%\t2.00 AU',
        ].join('\n'),
      );
      await sim.splashAndLink('default', '31000001', '31000101', 'ZRO-000', 'C3');
      expect(sim.lastClipboardText).toBe('0/A C3');
      expect(sim.getSystem('31000101').tag).toBe('A');

      await sim.splashAndLink('default', '31000001', '31000102', 'ONE-111', 'C4');
      expect(sim.lastClipboardText).toBe('1/B C4');
      expect(sim.getSystem('31000102').tag).toBe('B');

      // 2. Manual connect Hop0_A ('A') -> Hop00_A0 with empty separator and startAtZero=true -> gets 'A0' ('00')
      await sim.manualConnect('default', '31000101', '31000103', 0);
      expect(sim.getSystem('31000103').tag).toBe('A0');

      // 3. Rename Hop0_A from 'A' to 'D' (index 3) and scan a hole in Hop00_A0 -> Hop000_A00:
      // Even with empty separator and letter tags ('A0'), renaming Hop0_A to 'D' propagates to 'D00' ('D00/D00 C5')!
      await sim.renameSystemTag('default', '31000101', 'D');
      await sim.pasteClipboard(
        'default',
        '31000103',
        'SUB-222\tCosmic Signature\tWormhole\tUnstable Wormhole\t100.0%\t1.00 AU',
      );
      await sim.splashAndLink('default', '31000103', '31000104', 'SUB-222', 'C5');
      expect(sim.lastClipboardText).toBe('D00/D00 C5');
      expect(sim.getSystem('31000104').tag).toBe('D00');
    });

    it('handles non-standard descriptive labels/badges ("Staging", "clear"), rolling/disconnecting a branch, and reverse-order upstream backfilling', async () => {
      const settings: UserSettings = {
        bookmark_name_format: '{chain_index} {dest_type} - {sig_letters}',
        bookmark_auto_temp_name: 'chain_index',
        system_auto_tag: 'chain_index',
        bookmark_return_hole_ignore: true,
        bookmark_return_hole_symbol: '<',
        bookmark_wormholes_start_at_zero: false,
        bookmark_custom_mapping: { chain_separator: '.' },
      };

      const sim = new MapWorkflowSimulator(settings);
      sim.addSystem('31000001', 2, 'Home');
      sim.addSystem('31000101', 3, 'Hop1');
      sim.addSystem('31000102', 4, 'Hop2_Rolled');
      sim.addSystem('31000103', 4, 'Hop2_Replacement');
      sim.addSystem('31000104', 5, 'Hop3');

      // ---------------------------------------------------------------------------
      // 1. Reverse-order scanning: Scout jumps Home -> Hop1 -> Hop2_Rolled WITHOUT pasting in Home or Hop1,
      // and scans/links SIG-023 in Hop2_Rolled -> Hop3 first!
      // ---------------------------------------------------------------------------
      sim.esiSplashWithoutPasting('31000001', '31000101');
      sim.esiSplashWithoutPasting('31000101', '31000102');

      await sim.pasteClipboard(
        'default',
        '31000102',
        'SIG-023\tCosmic Signature\tWormhole\tUnstable Wormhole\t100.0%\t1.00 AU',
      );
      await sim.splashAndLink('default', '31000102', '31000104', 'SIG-023', 'C5');
      expect(sim.lastClipboardText).toBe('1.1.1 C5 - SIG');
      expect(sim.getSystem('31000104').tag).toBe('1.1.1');

      // Now another scout backfills Home by pasting 2 signatures and linking the 2nd signature (HOM-200, index 2) to Hop1!
      await sim.pasteClipboard(
        'default',
        '31000001',
        [
          'HOM-100\tCosmic Signature\tWormhole\tUnstable Wormhole\t100.0%\t1.00 AU',
          'HOM-200\tCosmic Signature\tWormhole\tUnstable Wormhole\t100.0%\t2.00 AU',
        ].join('\n'),
      );
      await sim.editSignature('default', '31000001', 'HOM-100', {
        group: SignatureGroup.Wormhole,
        type: 'C247',
        destType: 'c3',
      });
      await sim.splashAndLink('default', '31000001', '31000101', 'HOM-200', 'C3');
      expect(sim.getSystem('31000101').tag).toBe('2');

      // Re-saving SIG-023 in Hop2_Rolled preserves its relative index 1 while updating its upstream chain prefix from '1.1.1' to '2.1.1'!
      await sim.editSignature('default', '31000102', 'SIG-023', {
        group: SignatureGroup.Wormhole,
        type: 'H296',
        destType: 'c5',
      });
      expect(sim.getSignature('31000102', 'SIG-023').temporary_name).toBe('2.1.1');
      expect(sim.lastClipboardText).toBe('2.1.1 C5 - SIG');
      expect(sim.getSystem('31000104').tag).toBe('2.1.1');

      // ---------------------------------------------------------------------------
      // 2. Non-standard descriptive customLabel ("Staging") and status badge ("clear") on Hop1 (tag '2'):
      // Must NOT break Hop1's chain index '2' (because "Staging" is not a valid bookmark index, it falls back to tag '2')!
      // ---------------------------------------------------------------------------
      await sim.renameSystemViaSettingsDialog('default', '31000101', {
        customLabel: 'Staging',
        statusLabels: ['clear'],
      });
      await sim.pasteClipboard(
        'default',
        '31000101',
        'HRA-100\tCosmic Signature\tWormhole\tUnstable Wormhole\t100.0%\t1.00 AU',
      );
      await sim.splashAndLink('default', '31000101', '31000102', 'HRA-100', 'C4');
      expect(sim.lastClipboardText).toBe('2.1 C4 - HRA');
      expect(sim.getSystem('31000102').tag).toBe('2.1');

      // ---------------------------------------------------------------------------
      // 3. Roll/disconnect Hop2_Rolled ('2.1') from Hop1 and scan a new hole HNW-200 -> Hop2_Replacement:
      // Because Hop2_Rolled is disconnected and HRA-100 is deleted, '2.1' is freed and reused for Hop2_Replacement!
      // ---------------------------------------------------------------------------
      await sim.rollBranch('default', '31000101', '31000102', 'HRA-100');
      await sim.pasteClipboard(
        'default',
        '31000101',
        'HNW-200\tCosmic Signature\tWormhole\tUnstable Wormhole\t100.0%\t2.00 AU',
      );
      await sim.splashAndLink('default', '31000101', '31000103', 'HNW-200', 'C4');
      expect(sim.lastClipboardText).toBe('2.1 C4 - HNW');
      expect(sim.getSystem('31000103').tag).toBe('2.1');
    });

    it('handles messy user errors: misclicking Wormhole->Relic, lowercase tags ("a"), double-linking 2 sigs to the same system, reverse-dragged manual connections, progressive 0%->100% pastes, manual-connect before paste, and unlinking customLabel', async () => {
      const messySettings: UserSettings = {
        bookmark_name_format: '{chain_index_letters} {dest_type} - {sig_letters}',
        bookmark_auto_temp_name: 'chain_index_letters',
        system_auto_tag: 'chain_index_letters',
        system_custom_label_name: 'chain_index',
        bookmark_return_hole_ignore: true,
        bookmark_return_hole_symbol: '<',
        bookmark_wormholes_start_at_zero: false,
        bookmark_custom_mapping: { chain_separator: '.' },
      };

      const sim = new MapWorkflowSimulator(messySettings);
      sim.addSystem('31000001', 2, 'Home', { locked: true });
      sim.addSystem('31000101', 3, 'Hop1_ManualFirst');
      sim.addSystem('31000102', 4, 'Hop2_ReverseDrag');
      sim.addSystem('31000201', 3, 'Hop1_SecondBranch');
      sim.addSystem('31000301', 5, 'Hop1_ThirdBranch');

      // ---------------------------------------------------------------------------
      // 1. User manually connects Home -> Hop1_ManualFirst BEFORE pasting any signatures:
      // Hop1_ManualFirst gets tag 'A' and customLabel '1'.
      // ---------------------------------------------------------------------------
      await sim.manualConnect('default', '31000001', '31000101', 0);
      expect(sim.getSystem('31000101').tag).toBe('A');
      expect(new LabelsManager(sim.getSystem('31000101').labels!).customLabel).toBe('1');

      // ---------------------------------------------------------------------------
      // 2. Progressive Probe Scanner pastes in Home:
      // Paste 1: 3 signatures at 0.0% Unknown (Cosmic Signature, no group yet).
      // Paste 2: MIS-100 resolves to Relic Site, WHA-200 and WHB-300 resolve to Wormholes!
      // ---------------------------------------------------------------------------
      await sim.pasteClipboard(
        'default',
        '31000001',
        [
          'MIS-100\tCosmic Signature\t\t\t0.0%\t1.00 AU',
          'WHA-200\tCosmic Signature\t\t\t0.0%\t2.00 AU',
          'WHB-300\tCosmic Signature\t\t\t0.0%\t3.00 AU',
        ].join('\n'),
      );
      expect(sim.getSignature('31000001', 'MIS-100').group).toBe(SignatureGroup.CosmicSignature);

      await sim.pasteClipboard(
        'default',
        '31000001',
        [
          'MIS-100\tCosmic Signature\tRelic Site\tRuined Guristas Monument\t100.0%\t1.00 AU',
          'WHA-200\tCosmic Signature\tWormhole\tUnstable Wormhole\t100.0%\t2.00 AU',
          'WHB-300\tCosmic Signature\tWormhole\tUnstable Wormhole\t100.0%\t3.00 AU',
        ].join('\n'),
      );

      // ---------------------------------------------------------------------------
      // 3. User accidentally edits MIS-100 and selects Group: Wormhole (and links to Hop1_SecondBranch),
      // then realizes it's a Relic Site and changes Group back to Relic Site!
      // - MIS-100's auto-generated temporary_name and bookmark_index must be stripped!
      // - Hop1_SecondBranch must have BOTH its auto-tag AND its auto-customLabel cleared!
      // ---------------------------------------------------------------------------
      await sim.editSignature('default', '31000001', 'MIS-100', {
        group: SignatureGroup.Wormhole,
        type: 'C247',
        destType: 'c3',
        linked_system: '31000201',
      });
      expect(sim.getSignature('31000001', 'MIS-100').temporary_name).toBe('B');
      expect(sim.getSystem('31000201').tag).toBe('B');
      expect(new LabelsManager(sim.getSystem('31000201').labels!).customLabel).toBe('2');

      // Now user fixes MIS-100 back to Relic Site:
      await sim.editSignature('default', '31000001', 'MIS-100', {
        group: SignatureGroup.RelicSite,
        name: 'Ruined Guristas Monument',
      });
      expect(sim.getSignature('31000001', 'MIS-100').temporary_name).toBe('');
      expect(JSON.parse(sim.getSignature('31000001', 'MIS-100').custom_info || '{}').bookmark_index).toBeUndefined();
      expect(sim.getSystem('31000201').linked_sig_eve_id).toBeNull();
      expect(sim.getSystem('31000201').tag).toBeNull();
      expect(new LabelsManager(sim.getSystem('31000201').labels || '').customLabel).toBe('');

      // ---------------------------------------------------------------------------
      // 4. Now user links WHA-200 to Hop1_ManualFirst (which already had tag 'A' from manualConnect in step 1):
      // WHA-200 must adopt index 1 ('A') instead of colliding with Hop1_ManualFirst's 'A' tag!
      // ---------------------------------------------------------------------------
      await sim.splashAndLink('default', '31000001', '31000101', 'WHA-200', 'C3');
      expect(sim.getSignature('31000001', 'WHA-200').temporary_name).toBe('A');
      expect(sim.lastClipboardText).toBe('A C3 - WHA');
      expect(sim.getSystem('31000101').tag).toBe('A');
      expect(sim.getSystem('31000101').linked_sig_eve_id).toBe('WHA-200');

      // ---------------------------------------------------------------------------
      // 5. Another user mistakenly links WHB-300 (a second wormhole in Home) to Hop1_ManualFirst as well!
      // WHB-300 gets index 2 ('B'), while Hop1_ManualFirst and WHA-200 ('A') are NOT overwritten with 'B'!
      // ---------------------------------------------------------------------------
      await sim.splashAndLink('default', '31000001', '31000101', 'WHB-300', 'C3');
      expect(sim.getSignature('31000001', 'WHB-300').temporary_name).toBe('B');
      expect(sim.getSignature('31000001', 'WHA-200').temporary_name).toBe('A');
      expect(sim.getSystem('31000101').tag).toBe('A');
      expect(sim.getSystem('31000101').linked_sig_eve_id).toBe('WHA-200');

      // User then fixes WHB-300 in SignatureSettings to point to Hop1_SecondBranch ('31000201'):
      await sim.editSignature('default', '31000001', 'WHB-300', {
        group: SignatureGroup.Wormhole,
        type: 'C247',
        destType: 'c3',
        linked_system: '31000201',
      });
      expect(sim.getSystem('31000201').tag).toBe('B');
      expect(sim.getSystem('31000201').linked_sig_eve_id).toBe('WHB-300');

      // ---------------------------------------------------------------------------
      // 6. User manually types a LOWERCASE tag 'c' on Hop1_SecondBranch:
      // Scanning a new hole WHC-400 in Home -> Hop1_ThirdBranch must treat lowercase 'c' as 'C' (collision!),
      // and assign 'D' (4) instead of 'C'!
      // ---------------------------------------------------------------------------
      await sim.renameSystemViaSettingsDialog('default', '31000201', { customLabel: 'c' });
      await sim.renameSystemTag('default', '31000201', 'c');
      await sim.pasteClipboard(
        'default',
        '31000001',
        'WHC-400\tCosmic Signature\tWormhole\tUnstable Wormhole\t100.0%\t4.00 AU',
      );
      await sim.splashAndLink('default', '31000001', '31000301', 'WHC-400', 'C5');
      expect(sim.getSignature('31000001', 'WHC-400').temporary_name).toBe('D');
      expect(sim.getSystem('31000301').tag).toBe('D');

      // ---------------------------------------------------------------------------
      // 7. User drags a manual connection in the WRONG direction: from brand-new Hop2_ReverseDrag ('source')
      // back to established Hop1_ManualFirst ('target')!
      // Must NOT overwrite Hop1_ManualFirst, and must instead auto-tag Hop2_ReverseDrag as 'A.1'!
      // Even though the stored connection has source='31000102' and target='31000101', subsequent return hole
      // detection and downstream hops from Hop2_ReverseDrag must still treat '31000101' as parent and '31000102' as child!
      // ---------------------------------------------------------------------------
      await sim.manualConnect('default', '31000102', '31000101', 0);
      expect(sim.getSystem('31000101').tag).toBe('A');
      expect(sim.getSystem('31000102').tag).toBe('A.1');

      sim.addSystem('31000103', 5, 'Hop3_AfterReverseDrag');
      await sim.pasteClipboard(
        'default',
        '31000102',
        [
          'RET-102\tCosmic Signature\tWormhole\tWormhole K162\t100.0%\t1.00 AU',
          'FWD-103\tCosmic Signature\tWormhole\tUnstable Wormhole\t100.0%\t2.00 AU',
        ].join('\n'),
      );
      await sim.editSignature('default', '31000102', 'RET-102', {
        group: SignatureGroup.Wormhole,
        type: 'K162',
        k162Type: 'c3',
        linked_system: '31000101',
      });
      expect(sim.getSignature('31000102', 'RET-102').temporary_name).toBe('<');
      expect(sim.getSystem('31000101').tag).toBe('A');

      await sim.splashAndLink('default', '31000102', '31000103', 'FWD-103', 'C5');
      expect(sim.getSignature('31000102', 'FWD-103').temporary_name).toBe('A.1.1');
      expect(sim.getSystem('31000103').tag).toBe('A.1.1');

      // ---------------------------------------------------------------------------
      // 8. Reverse-dragging a manual connection directly into locked Home ('31000401' -> '31000001'):
      // - Auto-tags '31000401' as 'E' (next root branch after A, B, c, D).
      // - Subsequent wormhole scanned in Home ('WHD-500' -> '31000501') must keep Home as root ('F'),
      //   never treating '31000401' ('E') as Home's parent ('E.1.1')!
      // ---------------------------------------------------------------------------
      sim.addSystem('31000401', 2, 'Hop1_ReverseToHome');
      sim.addSystem('31000501', 4, 'Hop1_AfterReverseToHome');
      await sim.manualConnect('default', '31000401', '31000001', 0);
      expect(sim.getSystem('31000401').tag).toBe('E');
      expect(sim.getSystem('31000001').tag).toBeNull();

      await sim.pasteClipboard(
        'default',
        '31000001',
        'WHD-500\tCosmic Signature\tWormhole\tUnstable Wormhole\t100.0%\t5.00 AU',
      );
      await sim.splashAndLink('default', '31000001', '31000501', 'WHD-500', 'C4');
      expect(sim.getSignature('31000001', 'WHD-500').temporary_name).toBe('F');
      expect(sim.getSystem('31000501').tag).toBe('F');
    });

    it('handles re-linking an already-linked signature to a new system, userSettings=null fallback on group change, and 2-digit root tags in compact chains', async () => {
      const zeroSettings: UserSettings = {
        bookmark_name_format: '{chain_index_letters} {dest_type} - {sig_letters}',
        bookmark_auto_temp_name: 'chain_index_letters',
        system_auto_tag: 'chain_index_letters',
        system_custom_label_name: 'chain_index',
        bookmark_return_hole_ignore: true,
        bookmark_return_hole_symbol: '<',
        bookmark_wormholes_start_at_zero: true,
        bookmark_custom_mapping: { chain_separator: '.' },
      };

      const sim = new MapWorkflowSimulator(zeroSettings);
      sim.addSystem('31000001', 2, 'Home', { locked: true });
      sim.addSystem('31000101', 3, 'WrongTargetA');
      sim.addSystem('31000102', 3, 'CorrectTargetB');

      // 1. Link WHA-100 in Home -> WrongTargetA ('31000101'):
      // With startAtZero=true, index 0 -> letter 'A', customLabel '0'.
      await sim.pasteClipboard(
        'default',
        '31000001',
        'WHA-100\tCosmic Signature\tWormhole\tUnstable Wormhole\t100.0%\t1.00 AU',
      );
      await sim.splashAndLink('default', '31000001', '31000101', 'WHA-100', 'C3');
      expect(sim.getSystem('31000101').tag).toBe('A');
      expect(new LabelsManager(sim.getSystem('31000101').labels!).customLabel).toBe('0');
      expect(sim.getSystem('31000101').temporary_name).toBe('A');

      // Simulate client state where linked_sig_eve_id has not yet synced onto WrongTargetA,
      // then re-link WHA-100 directly to CorrectTargetB ('31000102') via executeLinkSignatureToSystem:
      // WrongTargetA must be cleaned up and CorrectTargetB must reuse 'A' (0) instead of colliding and becoming 'B' (1)!
      sim.getSystem('31000101').linked_sig_eve_id = null;
      await executeLinkSignatureToSystem({
        signature: sim.getSignature('31000001', 'WHA-100'),
        data: {
          solar_system_source: 31000001,
          solar_system_target: 31000102,
        },
        targetSystemClassGroup: 'C3',
        userSettings: null, // Forces fallback to OutCommand.getUserSettings
        systemSignatures: sim.systemSignatures,
        systems: sim.systems,
        wormholesData: {},
        connections: sim.connections,
        outCommand: sim.createOutCommand('default'),
      });
      expect(sim.getSystem('31000101').tag).toBeNull();
      expect(new LabelsManager(sim.getSystem('31000101').labels || '').customLabel).toBe('');
      expect(sim.getSystem('31000101').temporary_name).toBeNull();
      expect(sim.getSystem('31000102').tag).toBe('A');
      expect(new LabelsManager(sim.getSystem('31000102').labels!).customLabel).toBe('0');

      // 2. Call executeSaveSignatureSettings with userSettings: null when changing WHA-100 from Wormhole -> RelicSite:
      // Must fetch userSettings via OutCommand.getUserSettings (seeing startAtZero=true where index 0 -> 'A')
      // and strip the auto-generated 'A' temporary_name!
      await executeSaveSignatureSettings({
        signatureData: sim.getSignature('31000001', 'WHA-100'),
        formValues: {
          group: SignatureGroup.RelicSite,
          name: 'Ruined Sansha Temple',
        },
        systemId: '31000001',
        userSettings: null,
        systemSignatures: sim.systemSignatures,
        systems: sim.systems,
        wormholesData: {},
        connections: sim.connections,
        outCommand: sim.createOutCommand('default'),
      });
      expect(sim.getSignature('31000001', 'WHA-100').temporary_name).toBe('');
      expect(sim.getSystem('31000102').tag).toBeNull();
      expect(new LabelsManager(sim.getSystem('31000102').labels || '').customLabel).toBe('');

      // 3. Compact numeric chain (separator: '') with a 2-digit root index '12' ('L' when 1-indexed)
      // and an unrelated incoming connection with index '555':
      // Must resolve '12' as 12th letter 'L' ('L1'), not split '12' into 'A2'!
      const compactSystems: SolarSystemRawType[] = [
        createMockSystem({ id: '31000901', tag: '555' }),
        createMockSystem({ id: '31000902', tag: '12' }),
      ];
      const compactConns: SolarSystemConnection[] = [
        createMockConnection({ id: 'c1', source: '31000901', target: '31000902', type: 0 }),
      ];
      const compactCalc = calculateBookmarkIndex(
        {},
        '31000902',
        '31000902',
        'SIG-900',
        false,
        '',
        compactSystems,
        compactConns,
      );
      expect(compactCalc.chained).toBe('121');
      expect(compactCalc.chainedLetters).toBe('L1');

      // 4. Auto-synced temporary_name when bookmark_auto_temp_name is disabled (undefined),
      // system_auto_tag is 'index' (single-hop), and system_custom_label_name is 'chain_index':
      // Backend syncs customLabel ('1.1') to sig.temporary_name; re-saving after upstream rename
      // must update customLabel to '5.1' while keeping single-hop tag '1' (not clobbering tag with '1.1')!
      const syncSim = new MapWorkflowSimulator({
        bookmark_name_format: '{chain_index} {dest_type}',
        bookmark_custom_mapping: { chain_separator: '.' },
        system_auto_tag: 'index',
        system_custom_label_name: 'chain_index',
        bookmark_auto_temp_name: undefined,
        bookmark_return_hole_ignore: true,
        bookmark_return_hole_symbol: '<',
      });
      syncSim.addSystem('31000001', 2, 'Home', { locked: true });
      syncSim.addSystem('31000201', 3, 'Hop1');
      syncSim.addSystem('31000202', 4, 'Hop2');
      syncSim.addSystem('31000203', 4, 'Hop2Alt');

      await syncSim.pasteClipboard(
        'default',
        '31000001',
        'WHA-111\tCosmic Signature\tWormhole\tUnstable Wormhole\t100.0%\t1.00 AU',
      );
      await syncSim.splashAndLink('default', '31000001', '31000201', 'WHA-111', 'C3');

      await syncSim.pasteClipboard(
        'default',
        '31000201',
        'WHB-111\tCosmic Signature\tWormhole\tUnstable Wormhole\t100.0%\t1.00 AU',
      );
      await syncSim.splashAndLink('default', '31000201', '31000202', 'WHB-111', 'C4');
      expect(syncSim.getSystem('31000202').tag).toBe('1');
      expect(new LabelsManager(syncSim.getSystem('31000202').labels!).customLabel).toBe('1.1');
      expect(syncSim.getSignature('31000201', 'WHB-111').temporary_name).toBe('1.1');

      // Paste & link a return hole in Hop2 pointing back to Hop1, then re-link WHA-111 or WHB-111:
      // First rename Hop1 customLabel to '5' and re-save WHB-111:
      await syncSim.renameSystemViaSettingsDialog('default', '31000201', { customLabel: '5' });
      await syncSim.editSignature('default', '31000201', 'WHB-111', {
        group: SignatureGroup.Wormhole,
        linked_system: '31000202',
      });
      expect(syncSim.getSystem('31000202').tag).toBe('1');
      expect(new LabelsManager(syncSim.getSystem('31000202').labels!).customLabel).toBe('5.1');
      expect(syncSim.getSignature('31000201', 'WHB-111').temporary_name).toBe('5.1');

      // Now add a return hole in Hop2 pointing back to Hop1, and unlink WHA-111 from Hop1:
      // Hop1's auto-tag must still be cleaned up despite Hop2 having a return hole pointing to Hop1!
      await syncSim.renameSystemViaSettingsDialog('default', '31000201', { customLabel: '1' });
      await syncSim.pasteClipboard('default', '31000202', 'RET-202\tCosmic Signature\tWormhole\tK162\t100.0%\t1.00 AU');
      await syncSim.splashAndLink('default', '31000202', '31000201', 'RET-202', 'C3');
      await syncSim.editSignature('default', '31000001', 'WHA-111', {
        group: SignatureGroup.Wormhole,
        linked_system: '31000203',
      });
      expect(syncSim.getSystem('31000201').tag).toBeNull();
      expect(new LabelsManager(syncSim.getSystem('31000201').labels || '').customLabel).toBe('');

      // 5. Multi-segment manual rename on a mid-chain system (e.g. '7.5' on Hop2) must be preserved
      // (not overwritten with '1.5' from Hop1), AND manual forward connect from a locked Home (0 sigs)
      // to a pre-scanned Hop1 (has sigs) must auto-tag Hop1 instead of treating it as a reverse drag!
      const lockSim = new MapWorkflowSimulator({
        bookmark_name_format: '{chain_index} {dest_type}',
        bookmark_custom_mapping: { chain_separator: '.' },
        system_auto_tag: 'chain_index',
        bookmark_auto_temp_name: 'chain_index',
      });
      lockSim.addSystem('31000800', 2, 'LockedHome', { locked: true });
      lockSim.addSystem('31000801', 3, 'PreScannedHop1');
      lockSim.addSystem('31000802', 4, 'Hop2ManualMultiPart');
      lockSim.addSystem('31000803', 5, 'Hop3Downstream');

      // User pastes sigs in PreScannedHop1 FIRST, then manually drags connection from LockedHome -> PreScannedHop1:
      await lockSim.pasteClipboard(
        'default',
        '31000801',
        'FWD-801\tCosmic Signature\tWormhole\tUnstable Wormhole\t100.0%\t1.00 AU',
      );
      await lockSim.manualConnect('default', '31000800', '31000801', 0);
      expect(lockSim.getSystem('31000801').tag).toBe('1');

      // Link FWD-801 -> Hop2ManualMultiPart ('1.1'), then manually rename Hop2ManualMultiPart to '7.5':
      await lockSim.splashAndLink('default', '31000801', '31000802', 'FWD-801', 'C4');
      expect(lockSim.getSystem('31000802').tag).toBe('1.1');
      await lockSim.renameSystemTag('default', '31000802', '7.5');

      // Connecting Hop2ManualMultiPart ('7.5') -> Hop3Downstream must preserve '7.5' and produce '7.5.1' (not '1.5.1')!
      await lockSim.manualConnect('default', '31000802', '31000803', 0);
      expect(lockSim.getSystem('31000803').tag).toBe('7.5.1');

      // 6. Pasted mid-chain system manually renamed in single-hop mode (`system_auto_tag: 'index'`)
      // must still prepend its parent's chain index ('1.5.1', not '5.1') for downstream signatures!
      const singleHopSim = new MapWorkflowSimulator({
        bookmark_name_format: '{chain_index} {dest_type}',
        bookmark_custom_mapping: { chain_separator: '.' },
        system_auto_tag: 'index',
        bookmark_auto_temp_name: 'index',
      });
      singleHopSim.addSystem('31000910', 2, 'SH_Home', { locked: true });
      singleHopSim.addSystem('31000911', 3, 'SH_Hop1');
      singleHopSim.addSystem('31000912', 4, 'SH_Hop2');
      singleHopSim.addSystem('31000913', 5, 'SH_Hop3');

      await singleHopSim.pasteClipboard(
        'default',
        '31000910',
        'SHA-111\tCosmic Signature\tWormhole\tUnstable Wormhole\t100.0%\t1.00 AU',
      );
      await singleHopSim.splashAndLink('default', '31000910', '31000911', 'SHA-111', 'C3');

      await singleHopSim.pasteClipboard(
        'default',
        '31000911',
        'SHB-111\tCosmic Signature\tWormhole\tUnstable Wormhole\t100.0%\t1.00 AU',
      );
      await singleHopSim.splashAndLink('default', '31000911', '31000912', 'SHB-111', 'C4');
      expect(singleHopSim.getSystem('31000912').tag).toBe('1');

      // Manually rename pasted SH_Hop2 from '1' to '5', then paste & link SH_Hop2 -> SH_Hop3:
      await singleHopSim.renameSystemTag('default', '31000912', '5');
      await singleHopSim.pasteClipboard(
        'default',
        '31000912',
        'SHC-111\tCosmic Signature\tWormhole\tUnstable Wormhole\t100.0%\t1.00 AU',
      );
      await singleHopSim.splashAndLink('default', '31000912', '31000913', 'SHC-111', 'C5');
      expect(singleHopSim.getSystem('31000913').tag).toBe('1');
      expect(singleHopSim.lastClipboardText).toBe('1.5.1 C5');

      // 7. Backwards connection (Hop1 -> Home) when BOTH systems have linked signatures to each other
      // and bookmark_return_hole_ignore is false: Hop1.linked_sig_eve_id points to Home's signature,
      // so normalizeChainConnections must prioritize hasPrimaryLinkedSigTo and orient Home -> Hop1!
      const bidirSystems: SolarSystemRawType[] = [
        createMockSystem({
          id: 'sys_home_bd',
          locked: true,
          system_static_info: {
            ...createMockSystem({ id: 'sys_home_bd' }).system_static_info,
            solar_system_id: 31000950,
          },
        }),
        createMockSystem({
          id: 'sys_hop1_bd',
          tag: '1',
          linked_sig_eve_id: 'FWD-BD1',
          system_static_info: {
            ...createMockSystem({ id: 'sys_hop1_bd' }).system_static_info,
            solar_system_id: 31000951,
          },
        }),
        createMockSystem({
          id: 'sys_hop2_bd',
          tag: '1',
          system_static_info: {
            ...createMockSystem({ id: 'sys_hop2_bd' }).system_static_info,
            solar_system_id: 31000952,
          },
        }),
      ];
      const bidirSigs: Record<string, SystemSignature[]> = {
        sys_home_bd: [
          createMockSignature({
            eve_id: 'FWD-BD1',
            group: SignatureGroup.Wormhole,
            linked_system: bidirSystems[1].system_static_info,
            custom_info: JSON.stringify({
              bookmark_index: 1,
              bookmark_index_chained: '1',
              bookmark_index_chained_letters: 'A',
            }),
          }),
        ],
        sys_hop1_bd: [
          createMockSignature({
            eve_id: 'BACK-BD1',
            group: SignatureGroup.Wormhole,
            linked_system: bidirSystems[0].system_static_info,
            custom_info: JSON.stringify({
              bookmark_index: 1,
              bookmark_index_chained: '1.1',
              bookmark_index_chained_letters: 'A.1',
            }),
          }),
        ],
      };
      const bidirConns: SolarSystemConnection[] = [
        // Persisted backwards (Hop1 -> Home) even though Hop1.linked_sig_eve_id === 'FWD-BD1'
        createMockConnection({ id: 'c_bd_1', source: 'sys_hop1_bd', target: 'sys_home_bd', type: 0 }),
        createMockConnection({ id: 'c_bd_2', source: 'sys_hop1_bd', target: 'sys_hop2_bd', type: 0 }),
      ];
      const bidirCalc = calculateBookmarkIndex(
        bidirSigs,
        'sys_hop1_bd',
        '31000951',
        'NEW-BD2',
        false,
        '.',
        bidirSystems,
        bidirConns,
        { bookmark_return_hole_ignore: false },
        '31000952', // Passed as solar_system_id while s.id is 'sys_hop2_bd'
      );
      // Target sys_hop2_bd (solar_system_id 31000952) is excluded from collision check,
      // and Hop1's chain index resolves to '1' (not cyclic with Home), so NEW-BD2 gets '1.2' (since BACK-BD1 has index 1)
      expect(bidirCalc.index).toBe(2);
      expect(bidirCalc.chained).toBe('1.2');

      // 8. In chained mode (`system_auto_tag: 'chain_index'`), manually renaming a Hop 2 system
      // from '1.2' (where `bookmark_index` is 2) to single-segment '2' must be treated as a manual override
      // (producing '2.1' for its children, not reverting to '1.2.1'), AND reverse-dragging from a newly
      // scanned leaf system (with pasted sigs) to an established parent system must orient Parent -> Leaf!
      lockSim.addSystem('31000804', 4, 'Hop2SecondChild');
      lockSim.addSystem('31000805', 5, 'Hop3FromRenamed2');
      await lockSim.pasteClipboard(
        'default',
        '31000801',
        'FWD-802\tCosmic Signature\tWormhole\tUnstable Wormhole\t100.0%\t2.00 AU',
      );
      await lockSim.splashAndLink('default', '31000801', '31000804', 'FWD-802', 'C4');
      expect(lockSim.getSystem('31000804').tag).toBe('1.2');

      // Manually rename Hop2SecondChild ('1.2', bookmark_index=2) to '2' via customLabel:
      await lockSim.renameSystemViaSettingsDialog('default', '31000804', { customLabel: '2' });

      // User jumps into Hop3FromRenamed2, pastes signatures in Hop3FromRenamed2 FIRST,
      // and then drags a manual connection backwards from Hop3FromRenamed2 -> Hop2SecondChild ('2'):
      await lockSim.pasteClipboard(
        'default',
        '31000805',
        'LEAF-805\tCosmic Signature\tGas Site\tBarren Perimeter Reservoir\t100.0%\t1.00 AU',
      );
      await lockSim.manualConnect('default', '31000805', '31000804', 0);
      expect(lockSim.getSystem('31000805').tag).toBe('2.1');

      // 9. Re-linking a signature with a manual temporary_name when auto-bookmark settings are disabled:
      // Cleanup of the previous target system's temporary_name must happen AFTER linkSignatureToSystem
      // so backend sync on the previous target does not wipe the signature's temporary_name!
      const noAutoSim = new MapWorkflowSimulator({
        bookmark_name_format: '',
        bookmark_auto_temp_name: '',
        system_auto_tag: '',
        system_custom_label_name: '',
      });
      noAutoSim.addSystem('31000700', 2, 'ManualHome');
      noAutoSim.addSystem('31000701', 3, 'OldTarget');
      noAutoSim.addSystem('31000702', 3, 'NewTarget');
      await noAutoSim.pasteClipboard(
        'default',
        '31000700',
        'MAN-701\tCosmic Signature\tWormhole\tUnstable Wormhole\t100.0%\t1.00 AU',
      );
      await noAutoSim.editSignature('default', '31000700', 'MAN-701', {
        group: SignatureGroup.Wormhole,
        temporary_name: 'MyC3',
        linked_system: '31000701',
      });
      expect(noAutoSim.getSystem('31000701').temporary_name).toBe('MyC3');

      await noAutoSim.splashAndLink('default', '31000700', '31000702', 'MAN-701', 'C3');
      expect(noAutoSim.getSystem('31000701').temporary_name).toBeNull();
      expect(noAutoSim.getSignature('31000700', 'MAN-701').temporary_name).toBe('MyC3');
      expect(noAutoSim.getSystem('31000702').temporary_name).toBe('MyC3');

      // 10. Manually marking a signature that already had bookmark_index=1 with the return hole symbol ('<')
      // frees index 1 for subsequent wormholes in the same system!
      await lockSim.editSignature('default', '31000801', 'FWD-801', {
        group: SignatureGroup.Wormhole,
        temporary_name: '<',
        linked_system: undefined,
      });
      const freedCalc = calculateBookmarkIndex(
        lockSim.systemSignatures,
        '31000801',
        '31000801',
        'NEW-809',
        false,
        '.',
        lockSim.systems,
        lockSim.connections,
        {
          bookmark_return_hole_ignore: true,
          bookmark_return_hole_symbol: '<',
          system_auto_tag: 'chain_index',
          bookmark_auto_temp_name: 'chain_index',
        },
      );
      expect(freedCalc.index).toBe(1);
      expect(freedCalc.chained).toBe('1.1');
    });
  });
});
