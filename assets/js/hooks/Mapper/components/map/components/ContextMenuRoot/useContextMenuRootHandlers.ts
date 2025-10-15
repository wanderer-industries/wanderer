import { OnMapAddSystemCallback } from '@/hooks/Mapper/components/map/map.types.ts';
import { recenterSystemsByBounds } from '@/hooks/Mapper/helpers/recenterSystems.ts';
import { OutCommand, OutCommandHandler, SolarSystemConnection, SolarSystemRawType } from '@/hooks/Mapper/types';
import { decodeUriBase64ToJson } from '@/hooks/Mapper/utils';
import { ctxManager } from '@/hooks/Mapper/utils/contextManager.ts';
import { ContextMenu } from 'primereact/contextmenu';
import React, { useCallback, useRef, useState } from 'react';
import { useReactFlow, XYPosition } from 'reactflow';

export type PasteSystemsAndConnections = {
  systems: SolarSystemRawType[];
  connections: SolarSystemConnection[];
};

type UseContextMenuRootHandlers = {
  onAddSystem?: OnMapAddSystemCallback;
  onCommand?: OutCommandHandler;
};

export const useContextMenuRootHandlers = ({ onAddSystem, onCommand }: UseContextMenuRootHandlers = {}) => {
  const rf = useReactFlow();
  const contextMenuRef = useRef<ContextMenu | null>(null);
  const [position, setPosition] = useState<XYPosition | null>(null);
  const [pasteSystemsAndConnections, setPasteSystemsAndConnections] = useState<PasteSystemsAndConnections>();

  const handleRootContext = async (e: React.MouseEvent<HTMLDivElement>) => {
    setPosition(rf.project({ x: e.clientX, y: e.clientY }));
    e.preventDefault();
    ctxManager.next('ctxRoot', contextMenuRef.current);
    contextMenuRef.current?.show(e);

    try {
      const text = await navigator.clipboard.readText();
      const result = decodeUriBase64ToJson(text);
      setPasteSystemsAndConnections(result as PasteSystemsAndConnections);
    } catch (err) {
      setPasteSystemsAndConnections(undefined);
      // do nothing
    }
  };

  const ref = useRef({ onAddSystem, position, pasteSystemsAndConnections, onCommand });
  ref.current = { onAddSystem, position, pasteSystemsAndConnections, onCommand };

  const onAddSystemCallback = useCallback(() => {
    ref.current.onAddSystem?.({ coordinates: position });
  }, [position]);

  const onPasteSystemsAnsConnections = useCallback(async () => {
    const { pasteSystemsAndConnections, onCommand, position } = ref.current;
    if (!position || !onCommand || !pasteSystemsAndConnections) {
      return;
    }

    const { systems } = recenterSystemsByBounds(pasteSystemsAndConnections.systems);

    await onCommand({
      type: OutCommand.manualPasteSystemsAndConnections,
      data: {
        systems: systems.map(({ position: srcPos, ...rest }) => ({
          position: { x: Math.round(srcPos.x + position.x), y: Math.round(srcPos.y + position.y) },
          ...rest,
        })),
        connections: pasteSystemsAndConnections.connections,
      },
    });
  }, []);

  return {
    handleRootContext,
    pasteSystemsAndConnections,
    contextMenuRef,
    onAddSystem: onAddSystemCallback,
    onPasteSystemsAnsConnections,
  };
};
