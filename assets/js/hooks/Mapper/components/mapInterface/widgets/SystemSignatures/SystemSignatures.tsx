import { Widget } from '@/hooks/Mapper/components/mapInterface/components';
import { InfoDrawer, LayoutEventBlocker, TooltipPosition, WdImgButton } from '@/hooks/Mapper/components/ui-kit';
import { SystemSignaturesContent } from './SystemSignaturesContent';
import {
  Setting,
  SystemSignatureSettingsDialog,
  COSMIC_SIGNATURE,
  COSMIC_ANOMALY,
  DEPLOYABLE,
  STRUCTURE,
  STARBASE,
  SHIP,
  DRONE,
} from './SystemSignatureSettingsDialog';
import { SignatureGroup } from '@/hooks/Mapper/types';

import React, { useCallback, useEffect, useState } from 'react';

import { PrimeIcons } from 'primereact/api';

import { useMapRootState } from '@/hooks/Mapper/mapRootProvider';

const settings: Setting[] = [
  { key: COSMIC_ANOMALY, name: 'Show Anomalies', value: true },
  { key: COSMIC_SIGNATURE, name: 'Show Cosmic Signatures', value: true },
  { key: DEPLOYABLE, name: 'Show Deployables', value: true },
  { key: STRUCTURE, name: 'Show Structures', value: true },
  { key: STARBASE, name: 'Show Starbase', value: true },
  { key: SHIP, name: 'Show Ships', value: true },
  { key: DRONE, name: 'Show Drones And Charges', value: true },
  { key: SignatureGroup.Wormhole, name: 'Show Wormholes', value: true },
  { key: SignatureGroup.RelicSite, name: 'Show Relic Sites', value: true },
  { key: SignatureGroup.DataSite, name: 'Show Data Sites', value: true },
  { key: SignatureGroup.OreSite, name: 'Show Ore Sites', value: true },
  { key: SignatureGroup.GasSite, name: 'Show Gas Sites', value: true },
  { key: SignatureGroup.CombatSite, name: 'Show Combat Sites', value: true },
];

const SIGNATURE_SETTINGS_KEY = 'wanderer_system_signature_settings_v1';

const defaultSettings = () => {
  return [...settings];
};

export const SystemSignatures = () => {
  const {
    data: { selectedSystems },
  } = useMapRootState();

  const [visible, setVisible] = useState(false);
  const [settings, setSettings] = useState<Setting[]>(defaultSettings);

  const [systemId] = selectedSystems;

  const isNotSelectedSystem = selectedSystems.length !== 1;

  const handleSettingsChange = useCallback((settings: Setting[]) => {
    setSettings(settings);
    localStorage.setItem(SIGNATURE_SETTINGS_KEY, JSON.stringify(settings));
    setVisible(false);
  }, []);

  useEffect(() => {
    const restoredSettings = localStorage.getItem(SIGNATURE_SETTINGS_KEY);

    if (restoredSettings) {
      setSettings(JSON.parse(restoredSettings));
    }
  }, []);

  return (
    <Widget
      label={
        <div className="flex justify-between items-center text-xs w-full h-full">
          <div className="flex gap-1">System Signatures</div>

          <LayoutEventBlocker className="flex gap-2.5">
            <WdImgButton
              className={PrimeIcons.QUESTION_CIRCLE}
              tooltip={{
                position: TooltipPosition.left,
                // @ts-ignore
                content: (
                  <div className="flex flex-col gap-1">
                    <InfoDrawer title={<b className="text-slate-50">How to add/update signature?</b>}>
                      In game you need select one or more signatures <br /> in list in{' '}
                      <b className="text-sky-500">Probe scanner</b>. <br /> Use next hotkeys:
                      <br />
                      <b className="text-sky-500">Shift + LMB</b> or <b className="text-sky-500">Ctrl + LMB</b>
                      <br /> or <b className="text-sky-500">Ctrl + A</b> for select all
                      <br />
                      and then use <b className="text-sky-500">Ctrl + C</b>, after you need to go <br />
                      here select Solar system and paste it with <b className="text-sky-500">Ctrl + V</b>
                    </InfoDrawer>
                    <InfoDrawer title={<b className="text-slate-50">How to select?</b>}>
                      For select any signature need click on that, <br /> with hotkeys{' '}
                      <b className="text-sky-500">Shift + LMB</b> or <b className="text-sky-500">Ctrl + LMB</b>
                    </InfoDrawer>
                    <InfoDrawer title={<b className="text-slate-50">How to delete?</b>}>
                      For delete any signature first of all you need select before
                      <br /> and then use <b className="text-sky-500">Backspace</b>
                    </InfoDrawer>
                  </div>
                ) as React.ReactNode,
              }}
            />
            <WdImgButton className={PrimeIcons.SLIDERS_H} onClick={() => setVisible(true)} />
          </LayoutEventBlocker>
        </div>
      }
    >
      {isNotSelectedSystem ? (
        <div className="w-full h-full flex justify-center items-center select-none text-center text-stone-400/80 text-sm">
          System is not selected
        </div>
      ) : (
        <SystemSignaturesContent systemId={systemId} settings={settings} />
      )}
      {visible && (
        <SystemSignatureSettingsDialog
          settings={settings}
          onCancel={() => setVisible(false)}
          onSave={handleSettingsChange}
        />
      )}
    </Widget>
  );
};
