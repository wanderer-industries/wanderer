import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { Widget } from '@/hooks/Mapper/components/mapInterface/components';
import { SystemSignaturesContent } from './SystemSignaturesContent';
import { SystemSignatureSettingsDialog } from './SystemSignatureSettingsDialog';
import { useMapRootState } from '@/hooks/Mapper/mapRootProvider';
import { SystemSignaturesHeader } from './SystemSignatureHeader';
import { useHotkey } from '@/hooks/Mapper/hooks/useHotkey';
import { getDeletionTimeoutMs } from '@/hooks/Mapper/components/mapInterface/widgets/SystemSignatures/constants.ts';
import { OutCommand, OutCommandHandler } from '@/hooks/Mapper/types/mapHandlers';
import { ExtendedSystemSignature } from '@/hooks/Mapper/types';
import { SETTINGS_KEYS, SIGNATURE_WINDOW_ID, SignatureSettingsType } from '@/hooks/Mapper/constants/signatures.ts';

/**
 * Custom hook for managing pending signature deletions and undo countdown.
 */
function useSignatureUndo(
  systemId: string | undefined,
  settings: SignatureSettingsType,
  outCommand: OutCommandHandler,
) {
  const [countdown, setCountdown] = useState<number>(0);
  const [pendingIds, setPendingIds] = useState<Set<string>>(new Set());
  const [deletedSignatures, setDeletedSignatures] = useState<ExtendedSystemSignature[]>([]);
  const intervalRef = useRef<number | null>(null);

  const addDeleted = useCallback((signatures: ExtendedSystemSignature[]) => {
    const newIds = signatures.map(sig => sig.eve_id);
    setPendingIds(prev => {
      const next = new Set(prev);
      newIds.forEach(id => next.add(id));
      return next;
    });
    setDeletedSignatures(prev => [...prev, ...signatures]);
  }, []);

  // Clear deleted signatures when system changes
  useEffect(() => {
    if (systemId) {
      setDeletedSignatures([]);
      setPendingIds(new Set());
      setCountdown(0);
      if (intervalRef.current != null) {
        clearInterval(intervalRef.current);
        intervalRef.current = null;
      }
    }
  }, [systemId]);

  // kick off or clear countdown whenever pendingIds changes
  useEffect(() => {
    // clear any existing timer
    if (intervalRef.current != null) {
      clearInterval(intervalRef.current);
      intervalRef.current = null;
    }

    if (pendingIds.size === 0) {
      setCountdown(0);
      setDeletedSignatures([]);
      return;
    }

    // determine timeout from settings
    const timeoutMs = getDeletionTimeoutMs(settings);

    setCountdown(Math.ceil(timeoutMs / 1000));

    // start new interval
    intervalRef.current = window.setInterval(() => {
      setCountdown(prev => {
        if (prev <= 1) {
          clearInterval(intervalRef.current!);
          intervalRef.current = null;
          setPendingIds(new Set());
          setDeletedSignatures([]);
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
    if (!systemId || pendingIds.size === 0) return;
    await outCommand({
      type: OutCommand.undoDeleteSignatures,
      data: { system_id: systemId, eve_ids: Array.from(pendingIds) },
    });
    setPendingIds(new Set());
    setDeletedSignatures([]);
    setCountdown(0);
    if (intervalRef.current != null) {
      clearInterval(intervalRef.current);
      intervalRef.current = null;
    }
  }, [systemId, pendingIds, outCommand]);

  return {
    pendingIds,
    countdown,
    deletedSignatures,
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
    storedSettings: { settingsSignatures, settingsSignaturesUpdate },
  } = useMapRootState();

  const [systemId] = selectedSystems;
  const isSystemSelected = useMemo(() => selectedSystems.length === 1, [selectedSystems.length]);
  const { pendingIds, countdown, deletedSignatures, addDeleted, handleUndo } = useSignatureUndo(
    systemId,
    settingsSignatures,
    outCommand,
  );

  useHotkey(true, ['z', 'Z'], (event: KeyboardEvent) => {
    if (pendingIds.size > 0 && countdown > 0) {
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
      settingsSignaturesUpdate(newSettings);
      setVisible(false);
    },
    [settingsSignaturesUpdate],
  );

  const handleLazyDeleteToggle = useCallback(
    (value: boolean) => {
      settingsSignaturesUpdate(prev => ({
        ...prev,
        [SETTINGS_KEYS.LAZY_DELETE_SIGNATURES]: value,
      }));
    },
    [settingsSignaturesUpdate],
  );

  const openSettings = useCallback(() => setVisible(true), []);

  return (
    <Widget
      label={
        <SystemSignaturesHeader
          sigCount={sigCount}
          lazyDeleteValue={settingsSignatures[SETTINGS_KEYS.LAZY_DELETE_SIGNATURES] as boolean}
          pendingCount={pendingIds.size}
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
          settings={settingsSignatures}
          deletedSignatures={deletedSignatures}
          onLazyDeleteChange={handleLazyDeleteToggle}
          onCountChange={handleCountChange}
          onSignatureDeleted={addDeleted}
        />
      )}

      {visible && (
        <SystemSignatureSettingsDialog
          settings={settingsSignatures}
          onCancel={() => setVisible(false)}
          onSave={handleSettingsSave}
        />
      )}
    </Widget>
  );
};

export default SystemSignatures;
