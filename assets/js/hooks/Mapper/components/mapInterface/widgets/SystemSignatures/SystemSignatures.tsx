import { useCallback, useEffect, useRef, useState } from 'react';
import { Widget } from '@/hooks/Mapper/components/mapInterface/components';
import { SystemSignaturesContent } from './SystemSignaturesContent';
import { SystemSignatureSettingsDialog } from './SystemSignatureSettingsDialog';
import { ExtendedSystemSignature, SystemSignature } from '@/hooks/Mapper/types';
import { useMapRootState } from '@/hooks/Mapper/mapRootProvider';
import { useHotkey } from '@/hooks/Mapper/hooks';
import { SystemSignaturesHeader } from './SystemSignatureHeader';
import useLocalStorageState from 'use-local-storage-state';
import {
  SETTINGS_KEYS,
  SETTINGS_VALUES,
  SIGNATURE_DELETION_TIMEOUTS,
  SIGNATURE_SETTING_STORE_KEY,
  SIGNATURE_WINDOW_ID,
  SIGNATURES_DELETION_TIMING,
  SignatureSettingsType,
} from '@/hooks/Mapper/components/mapInterface/widgets/SystemSignatures/constants.ts';
import { calculateTimeRemaining } from './helpers';

export const SystemSignatures = () => {
  const [visible, setVisible] = useState(false);
  const [sigCount, setSigCount] = useState<number>(0);
  const [pendingSigs, setPendingSigs] = useState<SystemSignature[]>([]);
  const [pendingTimeRemaining, setPendingTimeRemaining] = useState<number | undefined>();
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
      setPendingTimeRemaining(undefined);
    }
  });

  const handleUndoClick = useCallback(() => {
    undoPendingFnRef.current();
    setPendingSigs([]);
    setPendingTimeRemaining(undefined);
  }, []);

  const handleSettingsButtonClick = useCallback(() => {
    setVisible(true);
  }, []);

  const handlePendingChange = useCallback(
    (pending: React.MutableRefObject<Record<string, ExtendedSystemSignature>>, newUndo: () => void) => {
      setPendingSigs(() => {
        return Object.values(pending.current).filter(sig => sig.pendingDeletion);
      });
      undoPendingFnRef.current = newUndo;
    },
    [],
  );

  // Calculate the minimum time remaining for any pending signature
  useEffect(() => {
    if (pendingSigs.length === 0) {
      setPendingTimeRemaining(undefined);
      return;
    }

    const calculate = () => {
      setPendingTimeRemaining(() => calculateTimeRemaining(pendingSigs));
    };

    calculate();
    const interval = setInterval(calculate, 1000);
    return () => clearInterval(interval);
  }, [pendingSigs]);

  return (
    <Widget
      label={
        <SystemSignaturesHeader
          sigCount={sigCount}
          lazyDeleteValue={currentSettings[SETTINGS_KEYS.LAZY_DELETE_SIGNATURES] as boolean}
          pendingCount={pendingSigs.length}
          pendingTimeRemaining={pendingTimeRemaining}
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
          deletionTiming={
            SIGNATURE_DELETION_TIMEOUTS[
              (currentSettings[SETTINGS_KEYS.DELETION_TIMING] as keyof typeof SIGNATURE_DELETION_TIMEOUTS) ||
                SIGNATURES_DELETION_TIMING.DEFAULT
            ] as number
          }
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
