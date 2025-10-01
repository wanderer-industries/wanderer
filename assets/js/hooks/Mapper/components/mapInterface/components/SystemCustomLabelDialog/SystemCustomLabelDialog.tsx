import { TooltipPosition, WdButton, WdImageSize, WdImgButton } from '@/hooks/Mapper/components/ui-kit';
import { getSystemById } from '@/hooks/Mapper/helpers';
import { useMapRootState } from '@/hooks/Mapper/mapRootProvider';
import { OutCommand } from '@/hooks/Mapper/types';
import { LabelsManager } from '@/hooks/Mapper/utils/labelsManager.ts';
import { Dialog } from 'primereact/dialog';
import { IconField } from 'primereact/iconfield';
import { InputText } from 'primereact/inputtext';
import { useCallback, useEffect, useRef, useState } from 'react';

interface SystemCustomLabelDialog {
  systemId: string;
  visible: boolean;
  setVisible: (visible: boolean) => void;
}

export const SystemCustomLabelDialog = ({ systemId, visible, setVisible }: SystemCustomLabelDialog) => {
  const {
    data: { systems },
    outCommand,
  } = useMapRootState();

  const system = getSystemById(systems, systemId);

  const [label, setLabel] = useState('');

  useEffect(() => {
    if (!system) {
      return;
    }

    const leb = new LabelsManager(system.labels || '');

    setLabel(leb.customLabel);
  }, [system]);

  const ref = useRef({ label, outCommand, systemId, system });
  ref.current = { label, outCommand, systemId, system };

  const handleSave = useCallback(() => {
    const { label, outCommand, system } = ref.current;

    if (!system) {
      return;
    }

    const outLabel = new LabelsManager(system.labels ?? '');
    outLabel.updateCustomLabel(label);

    outCommand({
      type: OutCommand.updateSystemLabels,
      data: {
        system_id: system.id,
        value: outLabel.toString(),
      },
    });

    setVisible(false);
  }, [setVisible]);

  const inputRef = useRef<HTMLInputElement>();

  const handleReset = useCallback(() => {
    setLabel('');
  }, []);

  const onShow = useCallback(() => {
    inputRef.current?.focus();
  }, []);

  const onHide = useCallback(() => {
    if (!visible) {
      return;
    }

    setVisible(false);
  }, [setVisible, visible]);

  // @ts-ignore
  const handleInput = useCallback(e => {
    e.target.value = e.target.value.toUpperCase().replace(/[^A-Z0-9\-[\](){}]/g, '');
  }, []);

  return (
    <Dialog
      header="Edit label"
      visible={visible}
      draggable={true}
      style={{ width: '250px' }}
      onHide={onHide}
      onShow={onShow}
    >
      <form onSubmit={handleSave}>
        <div className="flex flex-col gap-3">
          <div className="flex flex-col gap-2">
            <div className="flex flex-col gap-1">
              <label htmlFor="username">Custom label</label>

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
                    onClick={handleReset}
                  />
                )}
                <InputText
                  id="username"
                  aria-describedby="username-help"
                  autoComplete="off"
                  value={label}
                  maxLength={5}
                  onChange={e => setLabel(e.target.value)}
                  // @ts-expect-error
                  ref={inputRef}
                  onInput={handleInput}
                />
              </IconField>
            </div>
          </div>

          <div className="flex gap-2 justify-end">
            <WdButton type="submit" onClick={handleSave} outlined size="small" label="Save"></WdButton>
          </div>
        </div>
      </form>
    </Dialog>
  );
};
