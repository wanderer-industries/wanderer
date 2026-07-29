import { useCallback, useEffect, useMemo, useState } from 'react';
import { InputText } from 'primereact/inputtext';
import { WdButton, WdTooltipWrapper } from '@/hooks/Mapper/components/ui-kit';
import { useMapSettings } from '../MapSettingsProvider';
import { UserSettingsRemoteProps } from '../types';
import {
  createLabelId,
  getDefaultSystemLabels,
  parseSystemLabels,
  SystemLabelDefinition,
} from '@/hooks/Mapper/constants/labels.ts';
import { SYSTEM_LABELS_SETTINGS_PROPS } from '../constants.ts';

type LabelRowProps = {
  label: SystemLabelDefinition;
  isFirst: boolean;
  isLast: boolean;
  onChange: (patch: Partial<SystemLabelDefinition>) => void;
  onMove: (offset: number) => void;
  onRemove: () => void;
};

const LabelRow = ({ label, isFirst, isLast, onChange, onMove, onRemove }: LabelRowProps) => {
  const [name, setName] = useState(label.name);

  useEffect(() => setName(label.name), [label.name]);

  return (
    <div className="grid grid-cols-[auto_1fr_auto_auto] items-center gap-2 shrink-0">
      <input
        type="color"
        className="w-[26px] h-[26px] bg-transparent border border-stone-700 rounded cursor-pointer p-0"
        value={label.color}
        onChange={e => onChange({ color: e.target.value })}
        title="Label color"
      />

      <InputText
        className="text-sm w-full py-1 px-2"
        value={name}
        onChange={e => setName(e.target.value)}
        onBlur={() => name !== label.name && onChange({ name })}
        placeholder="Label name"
      />

      <div className="flex gap-1">
        <WdButton
          size="small"
          outlined
          icon="pi pi-arrow-up"
          className="text-xs py-1 px-2 h-auto min-h-[24px]"
          disabled={isFirst}
          onClick={() => onMove(-1)}
        />
        <WdButton
          size="small"
          outlined
          icon="pi pi-arrow-down"
          className="text-xs py-1 px-2 h-auto min-h-[24px]"
          disabled={isLast}
          onClick={() => onMove(1)}
        />
      </div>

      <WdTooltipWrapper content="Systems already tagged with this label keep the raw id until re-labelled">
        <WdButton
          size="small"
          outlined
          severity="danger"
          icon="pi pi-trash"
          className="text-xs py-1 px-2 h-auto min-h-[24px]"
          onClick={onRemove}
        />
      </WdTooltipWrapper>
    </div>
  );
};

export const LabelsSettings = () => {
  const { settings, updateSetting, renderSettingItem } = useMapSettings();

  const labels = useMemo(() => parseSystemLabels(settings.system_labels), [settings.system_labels]);

  const saveLabels = useCallback(
    (next: SystemLabelDefinition[]) => updateSetting(UserSettingsRemoteProps.system_labels, next),
    [updateSetting],
  );

  const handleChange = useCallback(
    (index: number, patch: Partial<SystemLabelDefinition>) =>
      saveLabels(labels.map((x, i) => (i === index ? { ...x, ...patch } : x))),
    [labels, saveLabels],
  );

  const handleMove = useCallback(
    (index: number, offset: number) => {
      const target = index + offset;

      if (target < 0 || target >= labels.length) {
        return;
      }

      const next = [...labels];
      [next[index], next[target]] = [next[target], next[index]];
      saveLabels(next);
    },
    [labels, saveLabels],
  );

  const handleRemove = useCallback(
    (index: number) => saveLabels(labels.filter((_, i) => i !== index)),
    [labels, saveLabels],
  );

  const handleAdd = useCallback(() => {
    const id = createLabelId(labels);
    saveLabels([...labels, { id, name: id.toUpperCase(), color: '#3d94af' }]);
  }, [labels, saveLabels]);

  const handleReset = useCallback(() => saveLabels(getDefaultSystemLabels()), [saveLabels]);

  return (
    <div className="w-full h-full min-h-0 flex flex-col gap-3 overflow-y-auto custom-scrollbar pr-1">
      <div className="flex justify-between items-center gap-2 shrink-0">
        <span className="text-stone-400 text-[12px]">
          Name is shown both in the right-click menu and on the system.
        </span>
        <WdButton size="small" outlined className="text-xs py-1 px-2 h-auto min-h-[24px]" onClick={handleReset}>
          Reset to Default
        </WdButton>
      </div>

      <div className="grid grid-cols-[auto_1fr_auto_auto] items-center gap-2 text-stone-500 text-[10px] uppercase tracking-wider shrink-0">
        <span>Color</span>
        <span>Name</span>
        <span>Order</span>
        <span />
      </div>

      <div className="flex flex-col gap-2 shrink-0">
        {labels.map((label, index) => (
          <LabelRow
            key={label.id}
            label={label}
            isFirst={index === 0}
            isLast={index === labels.length - 1}
            onChange={patch => handleChange(index, patch)}
            onMove={offset => handleMove(index, offset)}
            onRemove={() => handleRemove(index)}
          />
        ))}
      </div>

      <div className="shrink-0">
        <WdButton
          size="small"
          outlined
          icon="pi pi-plus"
          label="Add label"
          className="text-xs py-1 px-2"
          onClick={handleAdd}
        />
      </div>

      <div className="border-b-2 border-dotted border-stone-700/50 h-px my-1 shrink-0" />

      {SYSTEM_LABELS_SETTINGS_PROPS.map(renderSettingItem)}
    </div>
  );
};
