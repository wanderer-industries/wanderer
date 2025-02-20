import React, { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { Widget } from '@/hooks/Mapper/components/mapInterface/components';
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
import { useMapRootState } from '@/hooks/Mapper/mapRootProvider';
import useMaxWidth from '@/hooks/Mapper/hooks/useMaxWidth';
import { useHotkey } from '@/hooks/Mapper/hooks';
import { COMPACT_MAX_WIDTH } from './constants';
import { renderHeaderLabel } from './renders';

const SIGNATURE_SETTINGS_KEY = 'wanderer_system_signature_settings_v5_5';
export const SHOW_DESCRIPTION_COLUMN_SETTING = 'show_description_column_setting';
export const SHOW_UPDATED_COLUMN_SETTING = 'SHOW_UPDATED_COLUMN_SETTING';
export const SHOW_CHARACTER_COLUMN_SETTING = 'SHOW_CHARACTER_COLUMN_SETTING';
export const LAZY_DELETE_SIGNATURES_SETTING = 'LAZY_DELETE_SIGNATURES_SETTING';
export const KEEP_LAZY_DELETE_SETTING = 'KEEP_LAZY_DELETE_ENABLED_SETTING';

const SETTINGS: Setting[] = [
  { key: SHOW_UPDATED_COLUMN_SETTING, name: 'Show Updated Column', value: false, isFilter: false },
  { key: SHOW_DESCRIPTION_COLUMN_SETTING, name: 'Show Description Column', value: false, isFilter: false },
  { key: SHOW_CHARACTER_COLUMN_SETTING, name: 'Show Character Column', value: false, isFilter: false },
  { key: LAZY_DELETE_SIGNATURES_SETTING, name: 'Lazy Delete Signatures', value: false, isFilter: false },
  { key: KEEP_LAZY_DELETE_SETTING, name: 'Keep "Lazy Delete" Enabled', value: false, isFilter: false },

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

function getDefaultSettings(): Setting[] {
  return [...SETTINGS];
}

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

  const undoPendingFnRef = useRef<() => void>(() => {});

  const handleSigCountChange = useCallback((count: number) => {
    setSigCount(count);
  }, []);

  const [systemId] = selectedSystems;
  const isNotSelectedSystem = selectedSystems.length !== 1;

  const lazyDeleteValue = useMemo(
    () => currentSettings.find(setting => setting.key === LAZY_DELETE_SIGNATURES_SETTING)?.value || false,
    [currentSettings]
  );

  const handleSettingsChange = useCallback((newSettings: Setting[]) => {
    setCurrentSettings(newSettings);
    setVisible(false);
  }, []);

  const handleLazyDeleteChange = useCallback((value: boolean) => {
    setCurrentSettings(prevSettings =>
      prevSettings.map(setting => (setting.key === LAZY_DELETE_SIGNATURES_SETTING ? { ...setting, value } : setting))
    );
  }, []);

  const containerRef = useRef<HTMLDivElement>(null);
  const isCompact = useMaxWidth(containerRef, COMPACT_MAX_WIDTH);

  useHotkey(true, ['z'], event => {
    if (pendingSigs.length > 0) {
      event.preventDefault();
      event.stopPropagation();
      undoPendingFnRef.current();
      setPendingSigs([]);
    }
  });

  const handleUndoClick = useCallback(() => {
    undoPendingFnRef.current();
    setPendingSigs([]);
  }, []);

  const handleSettingsButtonClick = useCallback(() => {
    setVisible(true);
  }, []);

  const handlePendingChange = useCallback((newPending: SystemSignature[], newUndo: () => void) => {
    setPendingSigs(prev => {
      if (newPending.length === prev.length && newPending.every(np => prev.some(pp => pp.eve_id === np.eve_id))) {
        return prev;
      }
      return newPending;
    });
    undoPendingFnRef.current = newUndo;
  }, []);

  return (
    <Widget
      label={
        <div ref={containerRef} className="w-full">
          {renderHeaderLabel({
            systemId,
            isNotSelectedSystem,
            isCompact,
            sigCount,
            lazyDeleteValue,
            pendingCount: pendingSigs.length,
            onLazyDeleteChange: handleLazyDeleteChange,
            onUndoClick: handleUndoClick,
            onSettingsClick: handleSettingsButtonClick,
          })}
        </div>
      }
    >
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
          onPendingChange={handlePendingChange}
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
