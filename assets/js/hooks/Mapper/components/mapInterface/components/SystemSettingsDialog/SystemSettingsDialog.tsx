import { useCallback, useEffect, useRef, useState, useMemo } from 'react';
import { Dialog } from 'primereact/dialog';
import { Button } from 'primereact/button';
import { IconField } from 'primereact/iconfield';
import { InputText } from 'primereact/inputtext';
import { InputTextarea } from 'primereact/inputtextarea';
import { AutoComplete } from 'primereact/autocomplete';

import { TooltipPosition, WdImageSize, WdImgButton } from '@/hooks/Mapper/components/ui-kit';
import { getSystemById } from '@/hooks/Mapper/helpers';
import { useMapRootState } from '@/hooks/Mapper/mapRootProvider';
import { useMapGetOption } from '@/hooks/Mapper/mapRootProvider/hooks/api';
import { OutCommand } from '@/hooks/Mapper/types';
import { LabelsManager } from '@/hooks/Mapper/utils/labelsManager';

interface SystemSettingsDialogProps {
  systemId: string;
  visible: boolean;
  setVisible: (visible: boolean) => void;
}

export const SystemSettingsDialog = ({ systemId, visible, setVisible }: SystemSettingsDialogProps) => {
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

  const [ownerName, setOwnerName] = useState('');
  const [ownerId, setOwnerId] = useState('');
  const [ownerType, setOwnerType] = useState<'corp' | 'alliance' | ''>('');
  const [ownerSuggestions, setOwnerSuggestions] = useState<string[]>([]);
  const [ownerMap, setOwnerMap] = useState<Record<string, { id: string; type: 'corp' | 'alliance' }>>({});
  const [prevOwnerQuery, setPrevOwnerQuery] = useState('');
  const [prevOwnerResults, setPrevOwnerResults] = useState<string[]>([]);

  const inputRef = useRef<HTMLInputElement>(null);

  const dataRef = useRef({
    name,
    label,
    temporaryName,
    description,
    ownerName,
    ownerId,
    ownerType,
    system,
  });
  dataRef.current = { name, label, temporaryName, description, ownerName, ownerId, ownerType, system };

  useEffect(() => {
    if (!system) return;

    const labelsManager = new LabelsManager(system.labels || '');
    setName(system.name || '');
    setLabel(labelsManager.customLabel);
    setTemporaryName(system.temporary_name || '');
    setDescription(system.description || '');

    setOwnerId(system.owner_id || '');
    setOwnerType((system.owner_type as 'corp' | 'alliance') || '');

    if (system.owner_id && system.owner_type) {
      if (system.owner_type === 'corp') {
        outCommand({
          type: OutCommand.getCorporationTicker,
          data: { corp_id: system.owner_id },
        }).then(({ ticker }) => setOwnerName(ticker || ''));
      } else {
        outCommand({
          type: OutCommand.getAllianceTicker,
          data: { alliance_id: system.owner_id },
        }).then(({ ticker }) => setOwnerName(ticker || ''));
      }
    } else {
      setOwnerName('');
    }
  }, [system, outCommand]);

  const searchOwners = useCallback(
    async (e: { query: string }) => {
      const newQuery = e.query.trim();
      if (!newQuery) {
        setOwnerSuggestions([]);
        setOwnerMap({});
        return;
      }
      if (newQuery.startsWith(prevOwnerQuery) && prevOwnerResults.length > 0) {
        const filtered = prevOwnerResults.filter(item => item.toLowerCase().includes(newQuery.toLowerCase()));
        setOwnerSuggestions(filtered);
        return;
      }
      try {
        const [corpRes, allianceRes] = await Promise.all([
          outCommand({ type: OutCommand.getCorporationNames, data: { search: newQuery } }),
          outCommand({ type: OutCommand.getAllianceNames, data: { search: newQuery } }),
        ]);
        const corpItems = (corpRes?.results || []).map((r: any) => ({
          name: r.label,
          id: r.value,
          type: 'corp' as const,
        }));
        const allianceItems = (allianceRes?.results || []).map((r: any) => ({
          name: r.label,
          id: r.value,
          type: 'alliance' as const,
        }));
        const merged = [...corpItems, ...allianceItems];
        const nameList = merged.map(m => m.name);
        const mapObj: Record<string, { id: string; type: 'corp' | 'alliance' }> = {};
        for (const item of merged) {
          mapObj[item.name] = { id: item.id, type: item.type };
        }
        setOwnerSuggestions(nameList);
        setOwnerMap(mapObj);
        setPrevOwnerQuery(newQuery);
        setPrevOwnerResults(nameList);
      } catch (err) {
        console.error('Failed to fetch owners:', err);
        setOwnerSuggestions([]);
        setOwnerMap({});
      }
    },
    [outCommand, prevOwnerQuery, prevOwnerResults],
  );

  const handleCustomLabelInput = useCallback((e: React.ChangeEvent<HTMLInputElement>) => {
    const raw = e.target.value.toUpperCase();
    const cleaned = raw.replace(/[^A-Z0-9\-[\](){}]/g, '');
    setLabel(cleaned);
  }, []);

  const validTickerRegex = useMemo(() => /^[A-Z0-9\-[\](){} ]+$/, []);

  const handleOwnerBlur = useCallback(() => {
    if (ownerName) {
      const foundKey = Object.keys(ownerMap).find(key => key.toUpperCase() === ownerName.toUpperCase());
      if (foundKey) {
        const found = ownerMap[foundKey];
        setOwnerName(foundKey);
        setOwnerId(found.id);
        setOwnerType(found.type);
      } else if (validTickerRegex.test(ownerName)) {
        setOwnerName(ownerName);
        setOwnerId('');
        setOwnerType('');
      } else {
        setOwnerName('');
        setOwnerId('');
        setOwnerType('');
      }
    }
  }, [ownerName, ownerMap, validTickerRegex]);

  const handleSave = useCallback(() => {
    const { name, label, temporaryName, description, ownerId, ownerType, system } = dataRef.current;
    if (!system) return;

    const lm = new LabelsManager(system.labels ?? '');
    lm.updateCustomLabel(label);
    outCommand({
      type: OutCommand.updateSystemLabels,
      data: { system_id: systemId, value: lm.toString() },
    });
    outCommand({
      type: OutCommand.updateSystemName,
      data: {
        system_id: systemId,
        value: name.trim() || system.system_static_info.solar_system_name,
      },
    });
    outCommand({
      type: OutCommand.updateSystemTemporaryName,
      data: { system_id: systemId, value: temporaryName },
    });
    outCommand({
      type: OutCommand.updateSystemDescription,
      data: { system_id: systemId, value: description },
    });
    outCommand({
      type: OutCommand.updateSystemOwner,
      data: { system_id: systemId, owner_id: ownerId, owner_type: ownerType },
    });
    setVisible(false);
  }, [outCommand, setVisible, systemId]);

  const onShow = useCallback(() => {
    inputRef.current?.focus();
  }, []);

  const handleInput = useCallback((e: React.FormEvent<HTMLInputElement>) => {
    const input = e.currentTarget;
    input.value = input.value.toUpperCase().replace(/[^A-Z0-9\-[\](){} ]/g, '');
  }, []);

  const handleResetSystemName = useCallback(() => {
    if (!system) return;
    setName(system.system_static_info.solar_system_name);
  }, [system]);

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
      <form
        onSubmit={e => {
          e.preventDefault();
          handleSave();
        }}
      >
        <div className="flex flex-col gap-3">
          <div className="flex flex-col gap-2">
            <div className="flex flex-col gap-1">
              <label htmlFor="name">Custom name</label>
              <IconField>
                {name !== system?.system_static_info.solar_system_name && (
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
                  ref={inputRef}
                  aria-describedby="name"
                  autoComplete="off"
                  value={name}
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
                  onChange={handleCustomLabelInput}
                />
              </IconField>
            </div>

            <div className="flex flex-col gap-1">
              <label htmlFor="owner">Owner</label>
              <IconField>
                {ownerName && (
                  <WdImgButton
                    className="pi pi-trash text-red-400"
                    textSize={WdImageSize.large}
                    tooltip={{
                      content: 'Clear Owner',
                      className: 'pi p-input-icon',
                      position: TooltipPosition.top,
                    }}
                    onClick={() => {
                      setOwnerName('');
                      setOwnerId('');
                      setOwnerType('');
                    }}
                  />
                )}
                <AutoComplete
                  id="owner"
                  className="w-full"
                  placeholder="Type to search (corp/alliance)"
                  suggestions={ownerSuggestions}
                  completeMethod={searchOwners}
                  value={ownerName}
                  forceSelection={true}
                  onInput={handleInput}
                  onSelect={e => {
                    const chosenName = e.value;
                    setOwnerName(chosenName);
                    const foundKey = Object.keys(ownerMap).find(key => key.toUpperCase() === chosenName.toUpperCase());
                    if (foundKey) {
                      const found = ownerMap[foundKey];
                      setOwnerId(found.id);
                      setOwnerType(found.type);
                    } else {
                      setOwnerId('');
                      setOwnerType('');
                    }
                  }}
                  onChange={e => {
                    setOwnerName(e.value);
                    setOwnerId('');
                    setOwnerType('');
                  }}
                  onBlur={handleOwnerBlur}
                />
              </IconField>
            </div>

            {isTempSystemNameEnabled && (
              <div className="flex flex-col gap-1">
                <label htmlFor="temporaryName">Temporary Name</label>
                <IconField>
                  {temporaryName && (
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
                    autoComplete="off"
                    maxLength={10}
                    value={temporaryName}
                    onChange={e => setTemporaryName(e.target.value)}
                  />
                </IconField>
              </div>
            )}
            <div className="flex flex-col gap-1">
              <label htmlFor="description">Description</label>
              <InputTextarea
                id="description"
                rows={5}
                autoResize
                value={description}
                onChange={e => setDescription(e.target.value)}
              />
            </div>
          </div>
          <div className="flex justify-end gap-2">
            <Button onClick={handleSave} outlined size="small" label="Save" />
          </div>
        </div>
      </form>
    </Dialog>
  );
};
