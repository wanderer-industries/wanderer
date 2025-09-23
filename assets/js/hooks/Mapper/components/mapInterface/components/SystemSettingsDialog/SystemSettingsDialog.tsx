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
import { getSystemStaticInfo } from '@/hooks/Mapper/mapRootProvider/hooks/useLoadSystemStatic';

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
  const systemStaticInfo = getSystemStaticInfo(systemId);

  const [name, setName] = useState('');
  const [label, setLabel] = useState('');
  const [temporaryName, setTemporaryName] = useState('');
  const [description, setDescription] = useState('');
  const inputRef = useRef<HTMLInputElement>();

  const ref = useRef({ name, description, temporaryName, label, outCommand, systemId, system, systemStaticInfo });
  ref.current = { name, description, label, temporaryName, outCommand, systemId, system, systemStaticInfo };

  const handleSave = useCallback(() => {
    const { name, description, label, temporaryName, outCommand, systemId, system, systemStaticInfo } = ref.current;

    const outLabel = new LabelsManager(system?.labels ?? '');
    outLabel.updateCustomLabel(label);

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
        value: name.trim() || systemStaticInfo?.solar_system_name,
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
    const { systemStaticInfo } = ref.current;
    if (!systemStaticInfo) {
      return;
    }
    setName(systemStaticInfo.solar_system_name);
  }, []);

  const onShow = useCallback(() => {
    inputRef.current?.focus();
  }, []);

  const handleInput = useCallback((e: any) => {
    e.target.value = e.target.value.toUpperCase().replace(/[^A-Z0-9\-[\](){}]/g, '');
  }, []);

  // Attention: this effect should be call only on mount.
  useEffect(() => {
    const { system } = ref.current;
    if (!system) {
      return;
    }

    const labels = new LabelsManager(system.labels || '');

    setName(system.name || '');
    setLabel(labels.customLabel);
    setTemporaryName(system.temporary_name || '');
    setDescription(system.description || '');
  }, []);

  return (
    <Dialog
      header="System settings"
      visible={visible}
      draggable={true}
      style={{ width: '450px' }}
      onShow={onShow}
      onHide={() => {
        if (!visible) {
          return;
        }

        setVisible(false);
      }}
    >
      <form onSubmit={handleSave}>
        <div className="flex flex-col gap-3">
          <div className="flex flex-col gap-2">
            <div className="flex flex-col gap-1">
              <label htmlFor="username">Custom name</label>

              <IconField>
                {name !== systemStaticInfo?.solar_system_name && (
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
                  value={name}
                  // @ts-expect-error
                  ref={inputRef}
                  onChange={e => setName(e.target.value)}
                />
              </IconField>
            </div>

            <div className="flex flex-col gap-1">
              <label htmlFor="label">Custom label</label>

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
                    onClick={() => setLabel('')}
                  />
                )}
                <InputText
                  id="label"
                  aria-describedby="label"
                  autoComplete="off"
                  value={label}
                  maxLength={5}
                  onChange={e => setLabel(e.target.value)}
                  onInput={handleInput}
                />
              </IconField>
            </div>

            {isTempSystemNameEnabled && (
              <div className="flex flex-col gap-1">
                <label htmlFor="username">Temporary Name</label>

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
                    value={temporaryName}
                    maxLength={12}
                    onChange={e => setTemporaryName(e.target.value)}
                  />
                </IconField>
              </div>
            )}

            <div className="flex flex-col gap-1">
              <label htmlFor="username">Description</label>
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
