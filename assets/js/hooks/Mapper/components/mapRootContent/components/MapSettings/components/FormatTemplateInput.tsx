import { InputText } from 'primereact/inputtext';
import { useCallback, useEffect, useRef, useState } from 'react';
import { WdButton } from '@/hooks/Mapper/components/ui-kit';
import { FORMAT_VARIABLES } from '@/hooks/Mapper/constants/formatVariables';
import { resolveAutoFormatTemplate } from '@/hooks/Mapper/helpers/bookmarkFormatHelper';

export interface FormatTemplateInputProps {
  label: string;
  value: string;
  placeholder?: string;
  helperText?: string;
  onChange: (value: string) => void;
}

export const FormatTemplateInput = ({ label, value, placeholder, helperText, onChange }: FormatTemplateInputProps) => {
  const inputRef = useRef<HTMLInputElement>(null);
  const [showVariables, setShowVariables] = useState(false);
  const [localValue, setLocalValue] = useState(() => resolveAutoFormatTemplate(value));

  useEffect(() => {
    setLocalValue(resolveAutoFormatTemplate(value));
  }, [value]);

  const commit = useCallback(
    (next: string) => {
      setLocalValue(next);

      if (next !== resolveAutoFormatTemplate(value)) {
        onChange(next);
      }
    },
    [onChange, value],
  );

  const insertVariable = useCallback(
    (variable: string) => {
      const input = inputRef.current;

      if (!input) {
        commit(localValue + variable);
        return;
      }

      const start = input.selectionStart ?? localValue.length;
      const end = input.selectionEnd ?? localValue.length;
      const next = localValue.substring(0, start) + variable + localValue.substring(end);

      commit(next);

      setTimeout(() => {
        input.focus();
        input.setSelectionRange(start + variable.length, start + variable.length);
      }, 0);
    },
    [commit, localValue],
  );

  return (
    <div className="flex flex-col gap-1 w-full mt-2 mb-2">
      <div className="flex justify-between items-end gap-2">
        <label className="text-[var(--gray-200)] text-[13px] select-none">{label}</label>
        <WdButton
          size="small"
          outlined
          className="text-xs py-1 px-2 h-auto min-h-[24px]"
          onClick={() => setShowVariables(prev => !prev)}
        >
          {showVariables ? 'Hide variables' : 'Variables'}
        </WdButton>
      </div>

      <InputText
        ref={inputRef}
        className="text-sm w-full"
        value={localValue}
        onChange={e => setLocalValue(e.target.value)}
        onBlur={e => commit(e.target.value)}
        placeholder={placeholder}
      />

      {helperText && <small className="text-gray-400 text-xs">{helperText}</small>}

      {showVariables && (
        <div className="overflow-y-auto custom-scrollbar pr-1 text-xs text-stone-400 p-2 bg-stone-800/50 rounded border border-stone-800 mt-1 max-h-[160px]">
          <h4 className="text-stone-300 font-semibold mb-2">Available Variables (Click to insert)</h4>
          <ul className="space-y-1">
            {FORMAT_VARIABLES.map(v => (
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
      )}
    </div>
  );
};
