import { useCallback, useRef, useState } from 'react';
import { Widget } from '@/hooks/Mapper/components/mapInterface/components';
import { SystemSignaturesContent } from './SystemSignaturesContent';
import { SystemSignatureSettingsDialog } from './SystemSignatureSettingsDialog';
import { SystemSignature } from '@/hooks/Mapper/types';
import { useMapRootState } from '@/hooks/Mapper/mapRootProvider';
import { useHotkey } from '@/hooks/Mapper/hooks';
import { SystemSignaturesHeader } from './SystemSignatureHeader';
import useLocalStorageState from 'use-local-storage-state';
import {
  SETTINGS_KEYS,
  SETTINGS_VALUES,
  SIGNATURE_SETTING_STORE_KEY,
  SIGNATURE_WINDOW_ID,
  SignatureSettingsType,
} from '@/hooks/Mapper/components/mapInterface/widgets/SystemSignatures/constants.ts';

export const SystemSignatures = () => {
  const [visible, setVisible] = useState(false);
  const [sigCount, setSigCount] = useState<number>(0);
  const [pendingSigs, setPendingSigs] = useState<SystemSignature[]>([]);
  const undoPendingFnRef = useRef<() => void>(() => {});

  const {
    data: { selectedSystems },
  } = useMapRootState();

  const [currentSettings, setCurrentSettings] = useLocalStorageState(SIGNATURE_SETTING_STORE_KEY, {
    defaultValue: SETTINGS_VALUES,
  });

  const handleSigCountChange = useCallback((count: number) => {
    setSigCount(count);
  }, []);

  const [systemId] = selectedSystems;
  const isNotSelectedSystem = selectedSystems.length !== 1;

  const handleSettingsChange = useCallback((newSettings: SignatureSettingsType) => {
    setCurrentSettings(newSettings);
    setVisible(false);
  }, []);

  const handleLazyDeleteChange = useCallback((value: boolean) => {
    setCurrentSettings(prev => ({ ...prev, [SETTINGS_KEYS.LAZY_DELETE_SIGNATURES]: value }));
  }, []);

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
        <SystemSignaturesHeader
          sigCount={sigCount}
          lazyDeleteValue={currentSettings[SETTINGS_KEYS.LAZY_DELETE_SIGNATURES] as boolean}
          // lazyDeleteValue={lazyDeleteValue}
          pendingCount={pendingSigs.length}
          onLazyDeleteChange={handleLazyDeleteChange}
          onUndoClick={handleUndoClick}
          onSettingsClick={handleSettingsButtonClick}
        />
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
