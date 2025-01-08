import { InputText } from 'primereact/inputtext';
import { InputTextarea } from 'primereact/inputtextarea';
import { Dialog } from 'primereact/dialog';
import { getSystemById } from '@/hooks/Mapper/helpers';
import { useMapRootState } from '@/hooks/Mapper/mapRootProvider';
import { useMapGetOption } from '@/hooks/Mapper/mapRootProvider/hooks/api';
import { useCallback, useEffect, useRef, useState } from 'react';
import { Button } from 'primereact/button';
import { OutCommand } from '@/hooks/Mapper/types';
import { IconField } from 'primereact/iconfield';
import { TooltipPosition, WdImageSize, WdImgButton } from '@/hooks/Mapper/components/ui-kit';
import { LabelsManager } from '@/hooks/Mapper/utils/labelsManager.ts';
import { Checkbox } from 'primereact/checkbox';

/** The tags you want as checkboxes. Each 'code' goes into label. */
const CHECKBOX_ITEMS = [
  { code: 'B',   label: 'Blobber' },
  { code: 'MB',  label: 'Marauder Blobber' },
  { code: 'C',   label: 'Check Notes' },
  { code: 'F',   label: 'Farm' },
  { code: 'PW',  label: 'Prewarp Sites' },
  { code: 'PT',  label: 'POS Trash' },
  { code: 'DNP', label: 'Do Not Pod' },
  { code: 'CF',  label: 'Coward Finder' },
];

/** Convert a string like "*B *MB *PT" → ["B", "MB", "PT"] */
function parseTagString(str: string): string[] {
  if (!str) return [];
  return str
    .trim()
    .split(/\s+/)          // split on whitespace
    .map(item => item.replace(/^\*/, '')) // remove leading '*'
    .filter(Boolean);
}

/** Convert an array like ["B", "MB", "PT"] → "*B *MB *PT" */
function toTagString(arr: string[]): string {
  return arr.map(code => `*${code}`).join(' ');
}

interface SystemSettingsDialog {
  systemId: string;
  visible: boolean;
  setVisible: (visible: boolean) => void;
}

export const SystemSettingsDialog = ({ systemId, visible, setVisible }: SystemSettingsDialog) => {
  const {
    data: { systems },
    outCommand,
  } = useMapRootState();

  const isTempSystemNameEnabled = useMapGetOption('show_temp_system_name') === 'true';

  const system = getSystemById(systems, systemId);

  const [name, setName] = useState('');
  const [label, setLabel] = useState('');
  const [temporaryName, setTemporaryName] = useState('');
  const [description, setDescription] = useState('');

  const [selectedTags, setSelectedTags] = useState<string[]>([]);

  const inputRef = useRef<HTMLInputElement>();

  useEffect(() => {
    if (!system) return;

    const labels = new LabelsManager(system.labels || '');

    setName(system.name || '');
    setLabel(labels.customLabel || '');
    setTemporaryName(system.temporary_name || '');
    setDescription(system.description || '');

    // Convert something like "*B *MB *PT" → ["B", "MB", "PT"]
    if (labels.customLabel) {
      setSelectedTags(parseTagString(labels.customLabel));
    } else {
      setSelectedTags([]);
    }
  }, [system]);

  const ref = useRef({
    name,
    description,
    label,
    temporaryName,
    selectedTags,
    outCommand,
    systemId,
    system,
  });
  ref.current = {
    name,
    description,
    label,
    temporaryName,
    selectedTags,
    outCommand,
    systemId,
    system,
  };

  const handleSave = useCallback(() => {
    const { name, description, temporaryName, selectedTags, outCommand, systemId, system } = ref.current;

    // Rebuild the label string, e.g. "*B *MB *PT"
    const joined = toTagString(selectedTags);

    const outLabel = new LabelsManager(system?.labels ?? '');
    outLabel.updateCustomLabel(joined);

    outCommand({
      type: OutCommand.updateSystemLabels,
      data: {
        system_id: systemId,
        value: outLabel.toString(),
      },
    });

    outCommand({
      type: OutCommand.updateSystemTemporaryName,
      data: {
        system_id: systemId,
        value: temporaryName,
      },
    });

    outCommand({
      type: OutCommand.updateSystemName,
      data: {
        system_id: systemId,
        value: name.trim() || system?.system_static_info.solar_system_name,
      },
    });

    outCommand({
      type: OutCommand.updateSystemDescription,
      data: {
        system_id: systemId,
        value: description,
      },
    });

    setVisible(false);
  }, [setVisible]);

  const handleResetSystemName = useCallback(() => {
    const { system } = ref.current;
    if (!system) return;
    setName(system.system_static_info.solar_system_name);
  }, []);

  const onShow = useCallback(() => {
    inputRef.current?.focus();
  }, []);

  const handleCheckbox = useCallback((code: string, checked: boolean) => {
    setSelectedTags(prev => {
      if (checked) {
        return [...prev, code];
      } else {
        return prev.filter(item => item !== code);
      }
    });
  }, []);

  return (
    <Dialog
      header="System settings"
      visible={visible}
      draggable={false}
      style={{ width: '450px' }}
      onShow={onShow}
      onHide={() => {
        if (!visible) return;
        setVisible(false);
      }}
    >
      <form onSubmit={handleSave}>
        <div className="flex flex-col gap-3">
          <div className="flex flex-col gap-2">
            {isTempSystemNameEnabled && (
              <div className="flex flex-col gap-1">
                <label htmlFor="username">Bookmark Name</label>
                <IconField>
                  {temporaryName !== '' && (
                    <WdImgButton
                      className="pi pi-trash text-red-400"
                      textSize={WdImageSize.large}
                      tooltip={{
                        content: 'Remove temporary name',
                        className: 'pi p-input-icon',
                        position: TooltipPosition.top,
                      }}
                      onClick={() => setTemporaryName('')}
                    />
                  )}
                  <InputText
                    id="temporaryName"
                    aria-describedby="temporaryName"
                    autoComplete="off"
                    ref={inputRef as any}
                    value={temporaryName}
                    maxLength={10}
                    onChange={e => setTemporaryName(e.target.value)}
                  />
                </IconField>
              </div>
            )}
            <div className="flex flex-col gap-1">
              <label htmlFor="username">Ticker</label>
              <IconField>
                {name !== system?.system_static_info?.solar_system_name && (
                  <WdImgButton
                    className="pi pi-undo"
                    textSize={WdImageSize.large}
                    tooltip={{
                      content: 'Reset system name',
                      className: 'pi p-input-icon',
                      position: TooltipPosition.top,
                    }}
                    onClick={handleResetSystemName}
                  />
                )}
                <InputText
                  id="name"
                  aria-describedby="name"
                  autoComplete="off"
                  value={
                    name !== system?.system_static_info?.solar_system_name ? name : ''
                  }
                  onChange={e => setName(e.target.value)}
                />
              </IconField>
            </div>
            <div className="flex flex-col gap-1">
              <label htmlFor="label">System Tags</label>
              <IconField>
                {label !== '' && (
                  <WdImgButton
                    className="pi pi-trash text-red-400"
                    textSize={WdImageSize.large}
                    tooltip={{
                      content: 'Remove custom label',
                      className: 'pi p-input-icon',
                      position: TooltipPosition.top,
                    }}
                    onClick={() => {
                      setLabel('');
                      setSelectedTags([]);
                    }}
                  />
                )}
                <div className="grid grid-cols-2 gap-2 pl-2">
                  {CHECKBOX_ITEMS.map(item => {
                    const checked = selectedTags.includes(item.code);
                    return (
                      <div key={item.code} className="flex items-center gap-2">
                        <Checkbox
                          inputId={item.code}
                          checked={checked}
                          onChange={e => handleCheckbox(item.code, e.checked)}
                        />
                        <label htmlFor={item.code}>{item.label}</label>
                      </div>
                    );
                  })}
                </div>
              </IconField>
            </div>
            <div className="flex flex-col gap-1">
              <label htmlFor="username">Notes</label>
              <InputTextarea
                autoResize
                rows={5}
                cols={30}
                value={description}
                onChange={e => setDescription(e.target.value)}
              />
            </div>
          </div>
          <div className="flex gap-2 justify-end">
            <Button onClick={handleSave} outlined size="small" label="Save"></Button>
          </div>
        </div>
      </form>
    </Dialog>
  );
};