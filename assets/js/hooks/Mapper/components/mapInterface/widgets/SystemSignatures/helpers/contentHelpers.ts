import { ExtendedSystemSignature, SystemSignature } from '@/hooks/Mapper/types';
import { FINAL_DURATION_MS } from '../constants';

export function prepareUpdatePayload(
  systemId: string,
  added: ExtendedSystemSignature[],
  updated: ExtendedSystemSignature[],
  removed: ExtendedSystemSignature[],
) {
  return {
    system_id: systemId,
    added: added.map(s => ({ ...s })),
    updated: updated.map(s => ({ ...s })),
    removed: removed.map(s => ({ ...s })),
  };
}

export function schedulePendingAdditionForSig(
  sig: ExtendedSystemSignature,
  finalDuration: number,
  setSignatures: React.Dispatch<React.SetStateAction<ExtendedSystemSignature[]>>,
  pendingAdditionMapRef: React.MutableRefObject<Record<string, { finalUntil: number; finalTimeoutId: number }>>,
  setPendingUndoAdditions: React.Dispatch<React.SetStateAction<ExtendedSystemSignature[]>>,
) {
  setPendingUndoAdditions(prev => [...prev, sig]);

  const now = Date.now();
  const finalTimeoutId = window.setTimeout(() => {
    setSignatures(prev =>
      prev.map(x => (x.eve_id === sig.eve_id ? { ...x, pendingAddition: false, pendingUntil: undefined } : x)),
    );
    const clone = { ...pendingAdditionMapRef.current };
    delete clone[sig.eve_id];
    pendingAdditionMapRef.current = clone;

    setPendingUndoAdditions(prev => prev.filter(x => x.eve_id !== sig.eve_id));
  }, finalDuration);

  pendingAdditionMapRef.current = {
    ...pendingAdditionMapRef.current,
    [sig.eve_id]: {
      finalUntil: now + finalDuration,
      finalTimeoutId,
    },
  };

  setSignatures(prev =>
    prev.map(x => (x.eve_id === sig.eve_id ? { ...x, pendingAddition: true, pendingUntil: now + finalDuration } : x)),
  );
}

export function mergeLocalPending(
  pendingMapRef: React.MutableRefObject<Record<string, ExtendedSystemSignature>>,
  serverSigs: ExtendedSystemSignature[],
): ExtendedSystemSignature[] {
  const now = Date.now();
  const pendingDeletions = Object.values(pendingMapRef.current).filter(
    sig => sig.pendingDeletion && sig.pendingUntil && sig.pendingUntil > now,
  );
  const mergedMap = new Map<string, ExtendedSystemSignature>();
  serverSigs.forEach(sig => mergedMap.set(sig.eve_id, sig));

  pendingDeletions.forEach(sig => {
    if (mergedMap.has(sig.eve_id)) {
      mergedMap.set(sig.eve_id, sig);
    }
  });
  return Array.from(mergedMap.values());
}

export function scheduleLazyTimers(
  signatures: ExtendedSystemSignature[],
  pendingMapRef: React.MutableRefObject<Record<string, ExtendedSystemSignature>>,
  finalizeFn: (sig: ExtendedSystemSignature) => Promise<void>,
  finalDuration = FINAL_DURATION_MS,
) {
  signatures.forEach(sig => {
    const finalTimeoutId = window.setTimeout(async () => {
      await finalizeFn(sig);
    }, finalDuration);

    pendingMapRef.current = {
      ...pendingMapRef.current,
      [sig.eve_id]: {
        ...sig,
        finalTimeoutId,
      },
    };
  });
}

export const calculateTimeRemaining = (pendingSigs: SystemSignature[]) => {
  const now = Date.now();
  let minTime: number | undefined = undefined;

  pendingSigs.forEach(sig => {
    const extendedSig = sig as unknown as { pendingUntil?: number };
    if (extendedSig.pendingUntil && (minTime === undefined || extendedSig.pendingUntil - now < minTime)) {
      minTime = extendedSig.pendingUntil - now;
    }
  });

  return minTime && minTime > 0 ? minTime : undefined;
};
