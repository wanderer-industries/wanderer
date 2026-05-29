import { useMapSettings } from '../MapSettingsProvider';
import { UserSettingsRemoteProps } from '../types';
import { InputText } from 'primereact/inputtext';
import { WdButton } from '@/hooks/Mapper/components/ui-kit';
import { useMemo, useState, useRef, useEffect, useCallback } from 'react';
import { formatBookmarkName } from '@/hooks/Mapper/helpers/bookmarkFormatHelper';
import { SignatureGroup, SignatureKind, SystemSignature } from '@/hooks/Mapper/types';
import { MassState, TimeStatus } from '@/hooks/Mapper/types/connection';

const DUMMY_SIG_BASE: SystemSignature = {
  eve_id: 'ABC-123',
  name: 'ABC-123',
  kind: SignatureKind.CosmicSignature,
  type: 'K162',
  description: 'To Jita',
  temporary_name: 'Temp',
  group: SignatureGroup.Wormhole,
  custom_info: '',
};

const VARIABLES = [
  { id: '{index}', desc: 'Numeric index (e.g., 1, 2, 3)' },
  { id: '{index_letter}', desc: 'Letter index (e.g., A, B, C)' },
  { id: '{chain_index}', desc: 'Numeric chain path (e.g., 11, 12, 121)' },
  { id: '{chain_index_letters}', desc: 'Letter chain path (e.g., A, A1, A21)' },
  { id: '{sig_letters}', desc: 'First 3 chars of signature (e.g., ABC)' },
  { id: '{sig}', desc: 'Full signature ID (e.g., ABC-123)' },
  { id: '{dest_type}', desc: 'Destination class (e.g., C5, HS, Thera)' },
  {
    id: '{dest_class_index}',
    desc: 'Letter index for multiple holes to same class (empty if only 1, otherwise a, b, c...)',
  },
  { id: '{type}', desc: 'Wormhole type (e.g., K162, H900)' },
  { id: '{size}', desc: 'Hole size (e.g., S, M, XL)' },
  { id: '{mass}', desc: 'Total mass in bil (e.g., 3.3)' },
  { id: '{time_status}', desc: 'Time remaining (e.g., 1H, 4H, 16H)' },
  { id: '{mass_status}', desc: 'Mass remaining (e.g., Destab, Crit)' },
  { id: '{temporary_name}', desc: 'Temporary name if set' },
  { id: '{description}', desc: 'Custom description' },
];

interface CustomMappingInputProps {
  mappingKey: string;
  label: string;
  defaultVal: string;
  savedMapping: Record<string, string>;
  localMapping: Record<string, string>;
  setLocalMapping: React.Dispatch<React.SetStateAction<Record<string, string>>>;
  updateSetting: (prop: any, value: any) => void;
}

const CustomMappingInput = ({
  mappingKey,
  label,
  defaultVal,
  savedMapping,
  localMapping,
  setLocalMapping,
  updateSetting,
}: CustomMappingInputProps) => {
  const value = localMapping[mappingKey] !== undefined ? localMapping[mappingKey] : defaultVal;

  const handleChange = useCallback((e: React.ChangeEvent<HTMLInputElement>) => {
    setLocalMapping(prev => {
      const newMapping = { ...prev };
      newMapping[mappingKey] = e.target.value;
      return newMapping;
    });
  }, [mappingKey, setLocalMapping]);

  const handleBlur = useCallback((e: React.FocusEvent<HTMLInputElement>) => {
    const val = e.target.value;
    setLocalMapping(prev => {
      const currentVal = prev[mappingKey] !== undefined ? prev[mappingKey] : defaultVal;
      if (val === currentVal) return prev;

      const newMapping = { ...prev };
      if (val === defaultVal) {
        delete newMapping[mappingKey];
      } else {
        newMapping[mappingKey] = val;
      }

      const savedVal = savedMapping[mappingKey] !== undefined ? savedMapping[mappingKey] : defaultVal;
      const newVal = newMapping[mappingKey] !== undefined ? newMapping[mappingKey] : defaultVal;

      if (newVal !== savedVal) {
        updateSetting(UserSettingsRemoteProps.bookmark_custom_mapping, newMapping);
      }
      return newMapping;
    });
  }, [mappingKey, defaultVal, savedMapping, setLocalMapping, updateSetting]);

  return (
    <div className="flex flex-col gap-1 w-[120px]">
      <label className="text-stone-400 text-[10px]">{label}</label>
      <InputText
        className="text-xs w-full py-1 px-2"
        value={value}
        onChange={handleChange}
        onBlur={handleBlur}
        placeholder="(empty)"
      />
    </div>
  );
};

const TIME_OPTIONS = [
  { key: 'time_1h', label: '1 Hour', defaultVal: '1H' },
  { key: 'time_4h', label: '4 Hours', defaultVal: '4H' },
  { key: 'time_4h30m', label: '4.5 Hours', defaultVal: '4.5H' },
  { key: 'time_16h', label: '16 Hours', defaultVal: '16H' },
  { key: 'time_24h', label: '24 Hours', defaultVal: '' },
  { key: 'time_48h', label: '48 Hours', defaultVal: '' },
];

const MASS_OPTIONS = [
  { key: 'mass_normal', label: 'Normal Mass', defaultVal: '' },
  { key: 'mass_half', label: 'Destab', defaultVal: 'Destab' },
  { key: 'mass_verge', label: 'Critical', defaultVal: 'Crit' },
];

const OTHER_OPTIONS = [{ key: 'chain_separator', label: 'Chain Separator', defaultVal: '' }];

const SIZE_OPTIONS = [
  { key: 'size_small', label: 'Small (Frigate)', defaultVal: 'S' },
  { key: 'size_medium', label: 'Medium', defaultVal: 'M' },
  { key: 'size_large', label: 'Large', defaultVal: '' },
  { key: 'size_freight', label: 'Huge / Freight', defaultVal: 'XL' },
  { key: 'size_capital', label: 'Capital', defaultVal: 'C' },
  { key: 'size_k162_unknown', label: 'Unknown (K162)', defaultVal: '' },
];

const CLASS_OPTIONS = [
  { key: 'class_c1', label: 'Class 1', defaultVal: 'C1' },
  { key: 'class_c2', label: 'Class 2', defaultVal: 'C2' },
  { key: 'class_c3', label: 'Class 3', defaultVal: 'C3' },
  { key: 'class_c4', label: 'Class 4', defaultVal: 'C4' },
  { key: 'class_c5', label: 'Class 5', defaultVal: 'C5' },
  { key: 'class_c6', label: 'Class 6', defaultVal: 'C6' },
  { key: 'class_c13', label: 'Class 13', defaultVal: 'C13' },
  { key: 'class_c1c2c3', label: 'Class 1/2/3', defaultVal: 'C1/C2/C3' },
  { key: 'class_c4c5', label: 'Class 4/5', defaultVal: 'C4/C5' },
  { key: 'class_hs', label: 'High-Sec', defaultVal: 'HS' },
  { key: 'class_ls', label: 'Low-Sec', defaultVal: 'LS' },
  { key: 'class_ns', label: 'Null-Sec', defaultVal: 'NS' },
  { key: 'class_thera', label: 'Thera', defaultVal: 'Thera' },
  { key: 'class_pochven', label: 'Pochven', defaultVal: 'Pochven' },
  { key: 'class_drifter', label: 'Drifter', defaultVal: 'Drifter' },
];

export const BookmarkNameFormatSetting = () => {
  const { settings, updateSetting } = useMapSettings();
  const formatStr = settings.bookmark_name_format || '';
  const customMapping = settings.bookmark_custom_mapping || {};
  const inputRef = useRef<HTMLInputElement>(null);

  const [localFormat, setLocalFormat] = useState(formatStr);
  const [localMapping, setLocalMapping] = useState(customMapping);
  const [showAdvanced, setShowAdvanced] = useState(false);

  useEffect(() => {
    setLocalFormat(formatStr);
  }, [formatStr]);

  useEffect(() => {
    setLocalMapping(customMapping);
  }, [customMapping]);

  const preview = useMemo(() => {
    const isZero = settings.bookmark_wormholes_start_at_zero;
    const sep = localMapping?.chain_separator || '';

    const chainNum = isZero ? `0${sep}0${sep}1` : `1${sep}1${sep}2`;
    const chainLet = isZero ? `A${sep}0${sep}1` : `A${sep}1${sep}2`;
    const currentIndex = isZero ? 1 : 2;

    const dummySig: SystemSignature = {
      ...DUMMY_SIG_BASE,
      type: 'V283',
      custom_info: JSON.stringify({
        time_status: TimeStatus._1h,
        mass_status: MassState.verge,
        bookmark_index_chained: chainNum,
        bookmark_index_chained_letters: chainLet,
      }),
    };

    const otherDummySig: SystemSignature = {
      ...DUMMY_SIG_BASE,
      type: 'V283',
      eve_id: 'DEF-456',
      name: 'DEF-456',
      custom_info: JSON.stringify({
        time_status: TimeStatus._1h,
        mass_status: MassState.verge,
      }),
    };

    const dummyWormholesData = {
      V283: {
        total_mass: 3300000000,
        max_mass_per_jump: 62000000,
        dest: ['hs'],
      } as any,
    };

    return formatBookmarkName(
      localFormat,
      dummySig,
      'HS',
      currentIndex,
      dummyWormholesData,
      isZero,
      localMapping,
      { preview_sys: [otherDummySig] },
      'preview_sys',
    );
  }, [localFormat, settings.bookmark_wormholes_start_at_zero, localMapping]);

  const handleBlur = useCallback(() => {
    if (localFormat !== formatStr) {
      updateSetting(UserSettingsRemoteProps.bookmark_name_format, localFormat);
    }
  }, [localFormat, formatStr, updateSetting]);

  const insertVariable = useCallback((variable: string) => {
    const input = inputRef.current;
    if (input) {
      const start = input.selectionStart || 0;
      const end = input.selectionEnd || 0;
      const newFormat = localFormat.substring(0, start) + variable + localFormat.substring(end);
      setLocalFormat(newFormat);
      updateSetting(UserSettingsRemoteProps.bookmark_name_format, newFormat);

      setTimeout(() => {
        input.focus();
        input.setSelectionRange(start + variable.length, start + variable.length);
      }, 0);
    } else {
      const newFormat = localFormat + variable;
      setLocalFormat(newFormat);
      updateSetting(UserSettingsRemoteProps.bookmark_name_format, newFormat);
    }
  }, [localFormat, updateSetting]);

  const resetToDefault = useCallback(() => {
    const defaultFormat = '{chain_index} {sig_letters} {dest_type} {size} {mass_status} {time_status}';
    setLocalFormat(defaultFormat);
    updateSetting(UserSettingsRemoteProps.bookmark_name_format, defaultFormat);
  }, [updateSetting]);

  const renderCustomMappingInputs = (options: { key: string; label: string; defaultVal: string }[]) => {
    return options.map(opt => (
      <CustomMappingInput
        key={opt.key}
        mappingKey={opt.key}
        label={opt.label}
        defaultVal={opt.defaultVal}
        savedMapping={customMapping}
        localMapping={localMapping}
        setLocalMapping={setLocalMapping}
        updateSetting={updateSetting}
      />
    ));
  };

  return (
    <div className="flex flex-col gap-3 mt-2">
      <div className="flex justify-between items-end">
        <label className="text-[var(--gray-200)] text-[13px] select-none">Bookmark Name Format</label>
        <WdButton size="small" outlined onClick={resetToDefault} className="text-xs py-1 px-2 h-auto min-h-[24px]">
          Reset to Default
        </WdButton>
      </div>
      <InputText
        ref={inputRef}
        className="text-sm w-full"
        value={localFormat}
        onChange={e => setLocalFormat(e.target.value)}
        onBlur={handleBlur}
        placeholder="e.g. {chain_index} {sig_letters} {dest_type} {size} {mass_status} {time_status}"
      />
      <div className="text-sm p-2 bg-stone-800 rounded border border-stone-700 flex flex-col gap-1">
        <span className="text-stone-400 text-xs">Live Preview:</span>
        <span className="text-stone-200 font-mono">
          {preview || <span className="italic text-stone-500">Empty</span>}
        </span>
      </div>

      <div className="flex-1 overflow-y-auto custom-scrollbar pr-1 text-xs text-stone-400 p-2 bg-stone-800/50 rounded border border-stone-800 mt-2 max-h-[160px]">
        <h4 className="text-stone-300 font-semibold mb-2">Available Variables (Click to insert)</h4>
        <ul className="space-y-1">
          {VARIABLES.map(v => (
            <li key={v.id}>
              <code
                className="text-stone-200 cursor-pointer hover:bg-stone-700 px-1 rounded transition-colors inline-block"
                onClick={() => insertVariable(v.id)}
              >
                {v.id}
              </code>{' '}
              - {v.desc}
            </li>
          ))}
        </ul>
      </div>

      <div className="mt-2">
        <WdButton
          className="text-xs w-full justify-center bg-stone-800 hover:bg-stone-700 border-stone-700 text-stone-300 py-1"
          onClick={() => setShowAdvanced(!showAdvanced)}
        >
          {showAdvanced ? 'Hide Advanced String Customization' : 'Show Advanced String Customization'}
        </WdButton>

        {showAdvanced && (
          <div className="p-3 bg-stone-900 rounded border border-stone-800 mt-2 flex flex-col gap-4">
            <div className="flex justify-between items-start">
              <p className="text-stone-400 text-xs italic">Override the default output of specific format variables.</p>
              <WdButton
                size="small"
                outlined
                className="text-xs py-1 px-2 h-auto min-h-[24px]"
                onClick={() => {
                  setLocalMapping({});
                  updateSetting(UserSettingsRemoteProps.bookmark_custom_mapping, {});
                }}
              >
                Reset Mappings
              </WdButton>
            </div>

            <div className="flex flex-col gap-2">
              <h5 className="text-stone-300 text-xs font-semibold uppercase tracking-wider">Time</h5>
              <div className="flex flex-wrap gap-2">{renderCustomMappingInputs(TIME_OPTIONS)}</div>
            </div>

            <div className="flex flex-col gap-2">
              <h5 className="text-stone-300 text-xs font-semibold uppercase tracking-wider">Mass</h5>
              <div className="flex flex-wrap gap-2">{renderCustomMappingInputs(MASS_OPTIONS)}</div>
            </div>

            <div className="flex flex-col gap-2">
              <h5 className="text-stone-300 text-xs font-semibold uppercase tracking-wider">Other / Formatting</h5>
              <div className="flex flex-wrap gap-2">{renderCustomMappingInputs(OTHER_OPTIONS)}</div>
            </div>

            <div className="flex flex-col gap-2">
              <h5 className="text-stone-300 text-xs font-semibold uppercase tracking-wider">Hole Sizes</h5>
              <div className="flex flex-wrap gap-2">{renderCustomMappingInputs(SIZE_OPTIONS)}</div>
            </div>

            <div className="flex flex-col gap-2">
              <h5 className="text-stone-300 text-xs font-semibold uppercase tracking-wider">Destination Classes</h5>
              <div className="flex flex-wrap gap-2">{renderCustomMappingInputs(CLASS_OPTIONS)}</div>
            </div>
          </div>
        )}
      </div>
    </div>
  );
};
