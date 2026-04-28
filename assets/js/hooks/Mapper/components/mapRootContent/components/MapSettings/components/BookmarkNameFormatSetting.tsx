import { useMapSettings } from '../MapSettingsProvider';
import { UserSettingsRemoteProps } from '../types';
import { InputText } from 'primereact/inputtext';
import { WdButton } from '@/hooks/Mapper/components/ui-kit';
import { useMemo, useState, useRef, useEffect } from 'react';
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
  { id: '{type}', desc: 'Wormhole type (e.g., K162, H900)' },
  { id: '{size}', desc: 'Hole size (e.g., S, M, XL)' },
  { id: '{mass}', desc: 'Total mass in bil (e.g., 3.3)' },
  { id: '{time_status}', desc: 'Time remaining (e.g., EoL, 4H, 16H)' },
  { id: '{mass_status}', desc: 'Mass remaining (e.g., Destab, Crit)' },
  { id: '{temporary_name}', desc: 'Temporary name if set' },
  { id: '{description}', desc: 'Custom description' },
];

export const BookmarkNameFormatSetting = () => {
  const { settings, updateSetting } = useMapSettings();
  const formatStr = settings.bookmark_name_format || '';
  const inputRef = useRef<HTMLInputElement>(null);

  const [localFormat, setLocalFormat] = useState(formatStr);

  useEffect(() => {
    setLocalFormat(formatStr);
  }, [formatStr]);

  const preview = useMemo(() => {
    const isZero = settings.bookmark_wormholes_start_at_zero;
    
    const chainNum = isZero ? `001` : `112`;
    const chainLet = isZero ? `A01` : `A12`;
    const currentIndex = isZero ? 1 : 2;

    const dummySig: SystemSignature = {
      ...DUMMY_SIG_BASE,
      custom_info: JSON.stringify({
        time_status: TimeStatus._1h,
        mass_status: MassState.half,
        bookmark_index_chained: chainNum,
        bookmark_index_chained_letters: chainLet,
      }),
    };

    return formatBookmarkName(
      localFormat,
      dummySig,
      'HS',
      currentIndex,
      {},
      isZero
    );
  }, [localFormat, settings.bookmark_wormholes_start_at_zero]);

  const handleBlur = () => {
    if (localFormat !== formatStr) {
      updateSetting(UserSettingsRemoteProps.bookmark_name_format, localFormat);
    }
  };

  const insertVariable = (variable: string) => {
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
  };

  const resetToDefault = () => {
    const defaultFormat = '{chain_index} {sig_letters} {dest_type} {size} {mass_status} {time_status}';
    setLocalFormat(defaultFormat);
    updateSetting(UserSettingsRemoteProps.bookmark_name_format, defaultFormat);
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
        <span className="text-stone-200 font-mono">{preview || <span className="italic text-stone-500">Empty</span>}</span>
      </div>

      <div className="flex-1 overflow-y-auto text-xs text-stone-400 p-2 bg-stone-800/50 rounded border border-stone-800 mt-2 max-h-[160px]">
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
    </div>
  );
};
