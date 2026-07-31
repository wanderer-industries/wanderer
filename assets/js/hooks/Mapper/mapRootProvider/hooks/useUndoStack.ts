import { useCallback, useRef, useState } from 'react';
import { SolarSystemConnection, SolarSystemRawType } from '@/hooks/Mapper/types';

export type UndoEntry = {
  // what was removed, captured before the delete goes to the server
  systems: SolarSystemRawType[];
  connections: SolarSystemConnection[];
};

export type UseUndoStackData = {
  pushUndoEntry: (entry: UndoEntry) => void;
  popUndoEntry: () => UndoEntry | undefined;
  canUndo: boolean;
};

// deletions are the only thing worth keeping, and only for as long as someone would still think
// of it as "the thing I just removed"
const UNDO_LIMIT = 20;

export const useUndoStack = (): UseUndoStackData => {
  const stackRef = useRef<UndoEntry[]>([]);
  const [canUndo, setCanUndo] = useState(false);

  const pushUndoEntry = useCallback((entry: UndoEntry) => {
    if (entry.systems.length === 0 && entry.connections.length === 0) {
      return;
    }

    stackRef.current = [...stackRef.current, entry].slice(-UNDO_LIMIT);
    setCanUndo(true);
  }, []);

  const popUndoEntry = useCallback(() => {
    const entry = stackRef.current[stackRef.current.length - 1];

    if (!entry) {
      return undefined;
    }

    stackRef.current = stackRef.current.slice(0, -1);
    setCanUndo(stackRef.current.length > 0);

    return entry;
  }, []);

  return { pushUndoEntry, popUndoEntry, canUndo };
};
