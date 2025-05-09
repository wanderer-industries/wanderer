import { useCallback, useState, useEffect, useRef, useMemo } from 'react';
import { Widget } from '@/hooks/Mapper/components/mapInterface/components';
import { SystemSignaturesContent } from './SystemSignaturesContent';
import { SystemSignatureSettingsDialog } from './SystemSignatureSettingsDialog';
import { useMapRootState } from '@/hooks/Mapper/mapRootProvider';
import { SystemSignaturesHeader } from './SystemSignatureHeader';
import useLocalStorageState from 'use-local-storage-state';
import { useHotkey } from '@/hooks/Mapper/hooks/useHotkey';
import {
  SETTINGS_KEYS,
  SETTINGS_VALUES,
  SIGNATURE_SETTING_STORE_KEY,
  SIGNATURE_WINDOW_ID,
  SignatureSettingsType,
  SIGNATURES_DELETION_TIMING,
  SIGNATURE_DELETION_TIMEOUTS,
} from '@/hooks/Mapper/components/mapInterface/widgets/SystemSignatures/constants.ts';
import { OutCommand, OutCommandHandler } from '@/hooks/Mapper/types/mapHandlers';

/**
 * Custom hook for managing pending signature deletions and undo countdown.
 */
function useSignatureUndo(
  systemId: string | undefined,
  settings: SignatureSettingsType,
  outCommand: OutCommandHandler,
) {
  const [pendingIds, setPendingIds] = useState<string[]>([]);
  const [countdown, setCountdown] = useState(0);
  const intervalRef = useRef<number | null>(null);

  const addDeleted = useCallback((ids: string[]) => {
    setPendingIds(prev => [...prev, ...ids]);
  }, []);

  // kick off or clear countdown whenever pendingIds changes
  useEffect(() => {
    // clear any existing timer
    if (intervalRef.current != null) {
      clearInterval(intervalRef.current);
      intervalRef.current = null;
    }

    if (pendingIds.length === 0) {
      setCountdown(0);
      return;
    }

    // determine timeout from settings
    const timingKey = Number(settings[SETTINGS_KEYS.DELETION_TIMING] ?? SIGNATURES_DELETION_TIMING.DEFAULT);
    const timeoutMs =
      Number(SIGNATURE_DELETION_TIMEOUTS[timingKey as keyof typeof SIGNATURE_DELETION_TIMEOUTS]) || 10000;
    setCountdown(Math.ceil(timeoutMs / 1000));

    // start new interval
    intervalRef.current = window.setInterval(() => {
      setCountdown(prev => {
        if (prev <= 1) {
          clearInterval(intervalRef.current!);
          intervalRef.current = null;
          setPendingIds([]);
          return 0;
        }
        return prev - 1;
      });
    }, 1000);

    return () => {
      if (intervalRef.current != null) {
        clearInterval(intervalRef.current);
        intervalRef.current = null;
      }
    };
  }, [pendingIds, settings]);

  // undo handler
  const handleUndo = useCallback(async () => {
    if (!systemId || pendingIds.length === 0) return;
    await outCommand({
      type: OutCommand.undoDeleteSignatures,
      data: { system_id: systemId, eve_ids: pendingIds },
    });
    setPendingIds([]);
    setCountdown(0);
    if (intervalRef.current != null) {
      clearInterval(intervalRef.current);
      intervalRef.current = null;
    }
  }, [systemId, pendingIds, outCommand]);

  return {
    pendingIds,
    countdown,
    addDeleted,
    handleUndo,
  };
}

export const SystemSignatures = () => {
  const [visible, setVisible] = useState(false);
  const [sigCount, setSigCount] = useState(0);

  const {
    data: { selectedSystems },
    outCommand,
  } = useMapRootState();

  const [currentSettings, setCurrentSettings] = useLocalStorageState<SignatureSettingsType>(
    SIGNATURE_SETTING_STORE_KEY,
    {
      defaultValue: SETTINGS_VALUES,
    },
  );

  const [systemId] = selectedSystems;
  const isSystemSelected = useMemo(() => selectedSystems.length === 1, [selectedSystems.length]);
  const { pendingIds, countdown, addDeleted, handleUndo } = useSignatureUndo(systemId, currentSettings, outCommand);

  useHotkey(true, ['z', 'Z'], (event: KeyboardEvent) => {
    if (pendingIds.length > 0 && countdown > 0) {
      event.preventDefault();
      event.stopPropagation();
      handleUndo();
    }
  });

  const handleCountChange = useCallback((count: number) => {
    setSigCount(count);
  }, []);

  const handleSettingsSave = useCallback(
    (newSettings: SignatureSettingsType) => {
      setCurrentSettings(newSettings);
      setVisible(false);
    },
    [setCurrentSettings],
  );

  const handleLazyDeleteToggle = useCallback(
    (value: boolean) => {
      setCurrentSettings(prev => ({
        ...prev,
        [SETTINGS_KEYS.LAZY_DELETE_SIGNATURES]: value,
      }));
    },
    [setCurrentSettings],
  );

  const openSettings = useCallback(() => setVisible(true), []);

  return (
    <Widget
      label={
        <SystemSignaturesHeader
          sigCount={sigCount}
          lazyDeleteValue={currentSettings[SETTINGS_KEYS.LAZY_DELETE_SIGNATURES] as boolean}
          pendingCount={pendingIds.length}
          undoCountdown={countdown}
          onLazyDeleteChange={handleLazyDeleteToggle}
          onUndoClick={handleUndo}
          onSettingsClick={openSettings}
        />
      }
      windowId={SIGNATURE_WINDOW_ID}
    >
      {!isSystemSelected ? (
        <div className="w-full h-full flex justify-center items-center select-none text-center text-stone-400/80 text-sm">
          System is not selected
        </div>
      ) : (
        <SystemSignaturesContent
          systemId={systemId}
          settings={currentSettings}
          onLazyDeleteChange={handleLazyDeleteToggle}
          onCountChange={handleCountChange}
          onSignatureDeleted={addDeleted}
        />
      )}

      {visible && (
        <SystemSignatureSettingsDialog
          settings={currentSettings}
          onCancel={() => setVisible(false)}
          onSave={handleSettingsSave}
        />
      )}
    </Widget>
  );
};

export default SystemSignatures;
