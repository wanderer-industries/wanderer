import { SignatureSettingsType } from '@/hooks/Mapper/constants/signatures';
import { ExtendedSystemSignature, OutCommandHandler } from '@/hooks/Mapper/types';
import { OutCommand } from '@/hooks/Mapper/types/mapHandlers';
import { useCallback, useEffect, useRef, useState } from 'react';
import { getDeletionTimeoutMs } from '../constants';

/**
 * Custom hook for managing pending signature deletions and undo countdown.
 */
export function useSignatureUndo(
  systemId: string | undefined,
  settings: SignatureSettingsType,
  deletedSignatures: ExtendedSystemSignature[],
  outCommand: OutCommandHandler,
) {
  const [countdown, setCountdown] = useState<number>(0);
  const intervalRef = useRef<number | null>(null);

  // Clear deleted signatures when system changes
  useEffect(() => {
    if (systemId) {
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

    if (deletedSignatures.length === 0) {
      setCountdown(0);
      return;
    }

    // determine timeout from settings
    const timeoutMs = getDeletionTimeoutMs(settings);

    // Ensure a minimum of 1 second for immediate deletion so the UI shows
    const effectiveTimeoutMs = timeoutMs === 0 ? 1000 : timeoutMs;

    setCountdown(Math.ceil(effectiveTimeoutMs / 1000));

    // start new interval
    intervalRef.current = window.setInterval(() => {
      setCountdown(prev => {
        if (prev <= 1) {
          clearInterval(intervalRef.current!);
          intervalRef.current = null;
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
  }, [deletedSignatures, settings]);

  // undo handler
  const handleUndo = useCallback(async () => {
    if (!systemId || deletedSignatures.length === 0) return;
    await outCommand({
      type: OutCommand.undoDeleteSignatures,
      data: { system_id: systemId, eve_ids: deletedSignatures.map(s => s.eve_id) },
    });
    setCountdown(0);
    if (intervalRef.current != null) {
      clearInterval(intervalRef.current);
      intervalRef.current = null;
    }
  }, [systemId, deletedSignatures, outCommand]);

  return {
    countdown,
    handleUndo,
  };
}
