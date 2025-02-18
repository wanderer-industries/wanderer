import React, { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { Widget } from '@/hooks/Mapper/components/mapInterface/components';
import {
  InfoDrawer,
  LayoutEventBlocker,
  SystemView,
  TooltipPosition,
  WdCheckbox,
  WdImgButton,
} from '@/hooks/Mapper/components/ui-kit';
import { SystemSignaturesContent } from './SystemSignaturesContent';
import {
  COSMIC_ANOMALY,
  COSMIC_SIGNATURE,
  DEPLOYABLE,
  DRONE,
  Setting,
  SHIP,
  STARBASE,
  STRUCTURE,
  SystemSignatureSettingsDialog,
} from './SystemSignatureSettingsDialog';
import { SignatureGroup, SystemSignature } from '@/hooks/Mapper/types';
import { PrimeIcons } from 'primereact/api';
import { useMapRootState } from '@/hooks/Mapper/mapRootProvider';
import { CheckboxChangeEvent } from 'primereact/checkbox';
import useMaxWidth from '@/hooks/Mapper/hooks/useMaxWidth';
import { WdTooltipWrapper } from '@/hooks/Mapper/components/ui-kit/WdTooltipWrapper';
import { useHotkey } from '@/hooks/Mapper/hooks';
import { COMPACT_MAX_WIDTH } from './constants';

const SIGNATURE_SETTINGS_KEY = 'wanderer_system_signature_settings_v5_3';
export const SHOW_DESCRIPTION_COLUMN_SETTING = 'show_description_column_setting';
export const SHOW_UPDATED_COLUMN_SETTING = 'SHOW_UPDATED_COLUMN_SETTING';
export const SHOW_CHARACTER_COLUMN_SETTING = 'SHOW_CHARACTER_COLUMN_SETTING';
export const LAZY_DELETE_SIGNATURES_SETTING = 'LAZY_DELETE_SIGNATURES_SETTING';
export const KEEP_LAZY_DELETE_SETTING = 'KEEP_LAZY_DELETE_ENABLED_SETTING';
export const HIDE_LINKED_SIGNATURES_SETTING = 'HIDE_LINKED_SIGNATURES_SETTING';

const SETTINGS: Setting[] = [
  { key: SHOW_UPDATED_COLUMN_SETTING, name: 'Show Updated Column', value: false, isFilter: false },
  { key: SHOW_DESCRIPTION_COLUMN_SETTING, name: 'Show Description Column', value: false, isFilter: false },
  { key: SHOW_CHARACTER_COLUMN_SETTING, name: 'Show Character Column', value: false, isFilter: false },
  { key: LAZY_DELETE_SIGNATURES_SETTING, name: 'Lazy Delete Signatures', value: false, isFilter: false },
  { key: KEEP_LAZY_DELETE_SETTING, name: 'Keep "Lazy Delete" Enabled', value: false, isFilter: false },
  { key: HIDE_LINKED_SIGNATURES_SETTING, name: 'Hide Linked Signatures', value: false, isFilter: false },

  { key: COSMIC_ANOMALY, name: 'Show Anomalies', value: true, isFilter: true },
  { key: COSMIC_SIGNATURE, name: 'Show Cosmic Signatures', value: true, isFilter: true },
  { key: DEPLOYABLE, name: 'Show Deployables', value: true, isFilter: true },
  { key: STRUCTURE, name: 'Show Structures', value: true, isFilter: true },
  { key: STARBASE, name: 'Show Starbase', value: true, isFilter: true },
  { key: SHIP, name: 'Show Ships', value: true, isFilter: true },
  { key: DRONE, name: 'Show Drones And Charges', value: true, isFilter: true },
  { key: SignatureGroup.Wormhole, name: 'Show Wormholes', value: true, isFilter: true },
  { key: SignatureGroup.RelicSite, name: 'Show Relic Sites', value: true, isFilter: true },
  { key: SignatureGroup.DataSite, name: 'Show Data Sites', value: true, isFilter: true },
  { key: SignatureGroup.OreSite, name: 'Show Ore Sites', value: true, isFilter: true },
  { key: SignatureGroup.GasSite, name: 'Show Gas Sites', value: true, isFilter: true },
  { key: SignatureGroup.CombatSite, name: 'Show Combat Sites', value: true, isFilter: true },
];

const getDefaultSettings = (): Setting[] => [...SETTINGS];

export const SystemSignatures: React.FC = () => {
  const {
    data: { selectedSystems },
  } = useMapRootState();

  const [visible, setVisible] = useState(false);

  const [currentSettings, setCurrentSettings] = useState<Setting[]>(() => {
    const stored = localStorage.getItem(SIGNATURE_SETTINGS_KEY);
    if (stored) {
      try {
        return JSON.parse(stored) as Setting[];
      } catch (error) {
        console.error('Error parsing stored settings', error);
      }
    }
    return getDefaultSettings();
  });

  useEffect(() => {
    localStorage.setItem(SIGNATURE_SETTINGS_KEY, JSON.stringify(currentSettings));
  }, [currentSettings]);

  const [sigCount, setSigCount] = useState<number>(0);
  const [pendingSigs, setPendingSigs] = useState<SystemSignature[]>([]);
  const [undoPending, setUndoPending] = useState<() => void>(() => () => {});

  const handleSigCountChange = useCallback((count: number) => {
    setSigCount(count);
  }, []);

  const [systemId] = selectedSystems;
  const isNotSelectedSystem = selectedSystems.length !== 1;

  const lazyDeleteValue = useMemo(
    () => currentSettings.find(setting => setting.key === LAZY_DELETE_SIGNATURES_SETTING)?.value || false,
    [currentSettings],
  );

  const handleSettingsChange = useCallback((newSettings: Setting[]) => {
    setCurrentSettings(newSettings);
    setVisible(false);
  }, []);

  const handleLazyDeleteChange = useCallback((value: boolean) => {
    setCurrentSettings(prevSettings =>
      prevSettings.map(setting => (setting.key === LAZY_DELETE_SIGNATURES_SETTING ? { ...setting, value } : setting)),
    );
  }, []);

  const containerRef = useRef<HTMLDivElement>(null);
  const isCompact = useMaxWidth(containerRef, COMPACT_MAX_WIDTH);

  useHotkey(true, ['z'], (event: KeyboardEvent) => {
    if (pendingSigs.length > 0) {
      event.preventDefault();
      event.stopPropagation();
      undoPending();
      setPendingSigs([]);
    }
  });

  const handleUndoClick = useCallback(() => {
    undoPending();
    setPendingSigs([]);
  }, [undoPending]);

  const handleSettingsButtonClick = useCallback(() => {
    setVisible(true);
  }, []);

  const renderLabel = () => (
    <div className="flex justify-between items-center text-xs w-full h-full" ref={containerRef}>
      <div className="flex justify-between items-center gap-1">
        {!isCompact && (
          <div className="flex whitespace-nowrap text-ellipsis overflow-hidden text-stone-400">
            {sigCount ? `[${sigCount}] ` : ''}Signatures {isNotSelectedSystem ? '' : 'in'}
          </div>
        )}
        {!isNotSelectedSystem && <SystemView systemId={systemId} className="select-none text-center" hideRegion />}
      </div>
      <LayoutEventBlocker className="flex gap-2.5">
        <WdTooltipWrapper content="Enable Lazy delete">
          <WdCheckbox
            size="xs"
            labelSide="left"
            label={isCompact ? '' : 'Lazy delete'}
            value={lazyDeleteValue}
            classNameLabel="text-stone-400 hover:text-stone-200 transition duration-300 whitespace-nowrap text-ellipsis overflow-hidden"
            onChange={(event: CheckboxChangeEvent) => handleLazyDeleteChange(!!event.checked)}
          />
        </WdTooltipWrapper>
        {pendingSigs.length > 0 && (
          <WdImgButton
            className={PrimeIcons.UNDO}
            style={{ color: 'red' }}
            tooltip={{ content: `Undo pending changes (${pendingSigs.length})` }}
            onClick={handleUndoClick}
          />
        )}
        <WdImgButton
          className={PrimeIcons.QUESTION_CIRCLE}
          tooltip={{
            position: TooltipPosition.left,
            content: (
              <div className="flex flex-col gap-1">
                <InfoDrawer title={<b className="text-slate-50">How to add/update signature?</b>}>
                  In game you need to select one or more signatures <br /> in the list in{' '}
                  <b className="text-sky-500">Probe scanner</b>. <br /> Use next hotkeys:
                  <br />
                  <b className="text-sky-500">Shift + LMB</b> or <b className="text-sky-500">Ctrl + LMB</b>
                  <br /> or <b className="text-sky-500">Ctrl + A</b> for select all
                  <br /> and then use <b className="text-sky-500">Ctrl + C</b>, after you need to go <br />
                  here, select Solar system and paste it with <b className="text-sky-500">Ctrl + V</b>
                </InfoDrawer>
                <InfoDrawer title={<b className="text-slate-50">How to select?</b>}>
                  For selecting any signature, click on it <br /> with hotkeys{' '}
                  <b className="text-sky-500">Shift + LMB</b> or <b className="text-sky-500">Ctrl + LMB</b>
                </InfoDrawer>
                <InfoDrawer title={<b className="text-slate-50">How to delete?</b>}>
                  To delete any signature, first select it <br /> and then press <b className="text-sky-500">Del</b>
                </InfoDrawer>
              </div>
            ) as React.ReactNode,
          }}
        />
        <WdImgButton className={PrimeIcons.SLIDERS_H} onClick={handleSettingsButtonClick} />
      </LayoutEventBlocker>
    </div>
  );

  return (
    <Widget label={renderLabel()}>
      {isNotSelectedSystem ? (
        <div className="w-full h-full flex justify-center items-center select-none text-center text-stone-400/80 text-sm">
          System is not selected
        </div>
      ) : (
        <SystemSignaturesContent
          systemId={systemId}
          settings={currentSettings}
          onLazyDeleteChange={handleLazyDeleteChange}
          onCountChange={handleSigCountChange}
          onPendingChange={(pending, undo) => {
            setPendingSigs(pending);
            setUndoPending(() => undo);
          }}
        />
      )}
      {visible && (
        <SystemSignatureSettingsDialog
          settings={currentSettings}
          onCancel={() => setVisible(false)}
          onSave={handleSettingsChange}
        />
      )}
    </Widget>
  );
};

export default SystemSignatures;
