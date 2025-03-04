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
import {
  COMPACT_MAX_WIDTH,
  DELETION_TIMING_DEFAULT,
  DELETION_TIMING_EXTENDED,
  DELETION_TIMING_IMMEDIATE,
  DELETION_TIMING_SETTING_KEY,
} from './constants';
import { renderHeaderLabel } from './renders';

const SIGNATURE_SETTINGS_KEY = 'wanderer_system_signature_settings_v5_5';
export const SIGNATURE_WINDOW_ID = 'system_signatures_window';
export const SHOW_DESCRIPTION_COLUMN_SETTING = 'show_description_column_setting';
export const SHOW_UPDATED_COLUMN_SETTING = 'SHOW_UPDATED_COLUMN_SETTING';
export const SHOW_CHARACTER_COLUMN_SETTING = 'SHOW_CHARACTER_COLUMN_SETTING';
export const LAZY_DELETE_SIGNATURES_SETTING = 'LAZY_DELETE_SIGNATURES_SETTING';
export const KEEP_LAZY_DELETE_SETTING = 'KEEP_LAZY_DELETE_ENABLED_SETTING';
// eslint-disable-next-line react-refresh/only-export-components
export const DELETION_TIMING_SETTING = DELETION_TIMING_SETTING_KEY;
export const COLOR_BY_TYPE_SETTING = 'COLOR_BY_TYPE_SETTING';
export const SHOW_CHARACTER_PORTRAIT_SETTING = 'SHOW_CHARACTER_PORTRAIT_SETTING';

// Extend the Setting type to include options for dropdown settings
type ExtendedSetting = Setting & {
  options?: { label: string; value: number }[];
};

const SETTINGS: ExtendedSetting[] = [
  { key: SHOW_UPDATED_COLUMN_SETTING, name: 'Show Updated Column', value: false, isFilter: false },
  { key: SHOW_DESCRIPTION_COLUMN_SETTING, name: 'Show Description Column', value: false, isFilter: false },
  { key: SHOW_CHARACTER_COLUMN_SETTING, name: 'Show Character Column', value: false, isFilter: false },
  { key: SHOW_CHARACTER_PORTRAIT_SETTING, name: 'Show Character Portrait in Tooltip', value: false, isFilter: false },
  { key: LAZY_DELETE_SIGNATURES_SETTING, name: 'Lazy Delete Signatures', value: false, isFilter: false },
  { key: KEEP_LAZY_DELETE_SETTING, name: 'Keep "Lazy Delete" Enabled', value: false, isFilter: false },
  { key: COLOR_BY_TYPE_SETTING, name: 'Color Signatures by Type', value: false, isFilter: false },
  {
    key: DELETION_TIMING_SETTING,
    name: 'Deletion Timing',
    value: DELETION_TIMING_DEFAULT,
    isFilter: false,
    options: [
      { label: '0s', value: DELETION_TIMING_IMMEDIATE },
      { label: '10s', value: DELETION_TIMING_DEFAULT },
      { label: '30s', value: DELETION_TIMING_EXTENDED },
    ],
  },

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

function getDefaultSettings(): ExtendedSetting[] {
  return [...SETTINGS];
}

function getInitialSettings(): ExtendedSetting[] {
  const stored = localStorage.getItem(SIGNATURE_SETTINGS_KEY);
  if (stored) {
    try {
      const parsedSettings = JSON.parse(stored) as ExtendedSetting[];
      // Merge stored settings with default settings to ensure new settings are included
      const defaultSettings = getDefaultSettings();
      const mergedSettings = defaultSettings.map(defaultSetting => {
        const storedSetting = parsedSettings.find(s => s.key === defaultSetting.key);
        if (storedSetting) {
          // Keep the stored value but ensure options are from default settings
          return {
            ...defaultSetting,
            value: storedSetting.value,
          };
        }
        return defaultSetting;
      });
      return mergedSettings;
    } catch (error) {
      console.error('Error parsing stored settings', error);
    }
  }
  return getDefaultSettings();
}

export const SystemSignatures: React.FC = () => {
  const {
    data: { selectedSystems },
  } = useMapRootState();

  const [visible, setVisible] = useState(false);

  const [currentSettings, setCurrentSettings] = useState<ExtendedSetting[]>(getInitialSettings);

  useEffect(() => {
    localStorage.setItem(SIGNATURE_SETTINGS_KEY, JSON.stringify(currentSettings));
  }, [currentSettings]);

  const [sigCount, setSigCount] = useState<number>(0);
  const [pendingSigs, setPendingSigs] = useState<SystemSignature[]>([]);
  const [minPendingTimeRemaining, setMinPendingTimeRemaining] = useState<number | undefined>(undefined);

  const undoPendingFnRef = useRef<() => void>(() => {});

  const handleSigCountChange = useCallback((count: number) => {
    setSigCount(count);
  }, []);

  const [systemId] = selectedSystems;
  const isNotSelectedSystem = selectedSystems.length !== 1;

  const lazyDeleteValue = useMemo(() => {
    const setting = currentSettings.find(setting => setting.key === LAZY_DELETE_SIGNATURES_SETTING);
    return typeof setting?.value === 'boolean' ? setting.value : false;
  }, [currentSettings]);

  const deletionTimingValue = useMemo(() => {
    const setting = currentSettings.find(setting => setting.key === DELETION_TIMING_SETTING);
    return typeof setting?.value === 'number' ? setting.value : DELETION_TIMING_IMMEDIATE;
  }, [currentSettings]);

  const colorByTypeValue = useMemo(() => {
    const setting = currentSettings.find(setting => setting.key === COLOR_BY_TYPE_SETTING);
    return typeof setting?.value === 'boolean' ? setting.value : false;
  }, [currentSettings]);

  const handleSettingsChange = useCallback((newSettings: Setting[]) => {
    setCurrentSettings(newSettings as ExtendedSetting[]);
    setVisible(false);
  }, []);

  const handleLazyDeleteChange = useCallback((value: boolean) => {
    setCurrentSettings(prevSettings =>
      prevSettings.map(setting => (setting.key === LAZY_DELETE_SIGNATURES_SETTING ? { ...setting, value } : setting)),
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
      setMinPendingTimeRemaining(undefined);
    }
  });

  const handleUndoClick = useCallback(() => {
    undoPendingFnRef.current();
    setPendingSigs([]);
    setMinPendingTimeRemaining(undefined);
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

  // Calculate the minimum time remaining for any pending signature
  useEffect(() => {
    if (pendingSigs.length === 0) {
      setMinPendingTimeRemaining(undefined);
      return;
    }

    const calculateTimeRemaining = () => {
      const now = Date.now();
      let minTime: number | undefined = undefined;

      pendingSigs.forEach(sig => {
        const extendedSig = sig as unknown as { pendingUntil?: number };
        if (extendedSig.pendingUntil && (minTime === undefined || extendedSig.pendingUntil - now < minTime)) {
          minTime = extendedSig.pendingUntil - now;
        }
      });

      setMinPendingTimeRemaining(minTime && minTime > 0 ? minTime : undefined);
    };

    calculateTimeRemaining();
    const interval = setInterval(calculateTimeRemaining, 1000);
    return () => clearInterval(interval);
  }, [pendingSigs]);

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
            pendingTimeRemaining: minPendingTimeRemaining,
            onLazyDeleteChange: handleLazyDeleteChange,
            onUndoClick: handleUndoClick,
            onSettingsClick: handleSettingsButtonClick,
          })}
        </div>
      }
      windowId={SIGNATURE_WINDOW_ID}
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
          deletionTiming={deletionTimingValue}
          colorByType={colorByTypeValue}
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
