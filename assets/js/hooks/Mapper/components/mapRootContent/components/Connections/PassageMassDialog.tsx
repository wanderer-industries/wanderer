import { WdButton, WdTooltipWrapper } from '@/hooks/Mapper/components/ui-kit';
import { PassageWithSourceTarget } from '@/hooks/Mapper/types';
import { Dialog } from 'primereact/dialog';
import { InputText } from 'primereact/inputtext';
import clsx from 'clsx';
import { useEffect, useMemo, useState } from 'react';
import { TimeAgo } from '@/hooks/Mapper/components/ui-kit';
import { kgToTons } from '@/hooks/Mapper/utils/kgToTons.ts';
import { getShipName } from './PassageCard/getShipName.ts';

type PassageMassDialogProps = {
  passage: PassageWithSourceTarget | null;
  visible: boolean;
  onHide: () => void;
  onSave: (mass: number) => Promise<void> | void;
};

const getPassageMass = (passage: PassageWithSourceTarget) => {
  return passage.mass ?? parseInt(passage.ship.ship_type_info.mass);
};

const parseMassValue = (value: string) => {
  const sanitized = value.replace(/[^\d]/g, '');

  if (sanitized === '') {
    return null;
  }

  const parsed = parseInt(sanitized);
  return Number.isFinite(parsed) && parsed > 0 ? parsed : null;
};

export const PassageMassDialog = ({ passage, visible, onHide, onSave }: PassageMassDialogProps) => {
  const [massValue, setMassValue] = useState('');
  const [saving, setSaving] = useState(false);

  useEffect(() => {
    if (!passage) {
      setMassValue('');
      return;
    }

    setMassValue(`${getPassageMass(passage)}`);
  }, [passage]);

  const parsedMass = useMemo(() => parseMassValue(massValue), [massValue]);

  const handleSave = async () => {
    if (!passage || parsedMass == null) {
      return;
    }

    setSaving(true);

    try {
      await onSave(parsedMass);
    } finally {
      setSaving(false);
    }
  };

  return (
    <Dialog
      header="Edit passage mass"
      visible={visible}
      draggable
      resizable={false}
      style={{ width: '420px' }}
      onHide={onHide}
    >
      {passage && (
        <div className="flex flex-col gap-4">
          <div className="rounded border border-stone-700/80 bg-stone-900/70 p-3">
            <div className="grid grid-cols-[34px_1fr_auto] gap-3 items-start">
              <div
                className="w-[34px] h-[34px] rounded-[3px] border border-stone-700 bg-center bg-cover bg-no-repeat"
                style={{ backgroundImage: `url(https://images.evetech.net/types/${passage.ship.ship_type_id}/icon)` }}
              />

              <div className="min-w-0">
                <div className="text-sm text-stone-100 truncate">{passage.ship.ship_type_info.name}</div>
                {passage.ship.ship_name && (
                  <div className="text-xs text-stone-400 truncate">{getShipName(passage.ship.ship_name)}</div>
                )}
                <div className="mt-2 flex items-center gap-2 text-xs text-stone-400">
                  <span>{passage.character.name}</span>
                  <span className="text-stone-600">|</span>
                  <WdTooltipWrapper content={new Date(passage.inserted_at).toLocaleString()}>
                    <span className="cursor-default">
                      <TimeAgo timestamp={passage.inserted_at} />
                    </span>
                  </WdTooltipWrapper>
                </div>
              </div>

              <div
                className={clsx(
                  'w-[34px] h-[34px] rounded-[3px] border border-stone-700 bg-center bg-cover bg-no-repeat',
                  'justify-self-end',
                )}
                style={{
                  backgroundImage: `url(https://images.evetech.net/characters/${passage.character.eve_id}/portrait)`,
                }}
              />
            </div>
          </div>

          <div className="flex flex-col gap-2">
            <label className="text-sm text-stone-300" htmlFor="passage-mass">
              Passage mass
            </label>

            <InputText
              id="passage-mass"
              value={massValue}
              onChange={event => setMassValue(event.target.value.replace(/[^\d]/g, ''))}
              placeholder="Mass in kg"
              className="w-full"
            />

            <div className="text-xs text-stone-500">
              {parsedMass == null ? 'Enter mass in kg' : `Preview: ${kgToTons(parsedMass)}`}
            </div>
          </div>

          <div className="flex justify-end gap-2">
            <WdButton outlined size="small" label="Cancel" onClick={onHide} />
            <WdButton
              outlined
              size="small"
              label={saving ? 'Saving...' : 'Save'}
              onClick={handleSave}
              disabled={parsedMass == null || saving}
            />
          </div>
        </div>
      )}
    </Dialog>
  );
};
