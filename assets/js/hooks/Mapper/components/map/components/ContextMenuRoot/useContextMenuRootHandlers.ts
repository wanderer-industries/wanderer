import { useReactFlow, XYPosition } from 'reactflow';
import React, { useRef, useState } from 'react';
import { ContextMenu } from 'primereact/contextmenu';
import { useMapState } from '../../MapProvider.tsx';
import { OutCommand } from '@/hooks/Mapper/types/mapHandlers.ts';
import { ctxManager } from '@/hooks/Mapper/utils/contextManager.ts';

export const useContextMenuRootHandlers = () => {
  const rf = useReactFlow();
  const contextMenuRef = useRef<ContextMenu | null>(null);
  const { outCommand } = useMapState();
  const [position, setPosition] = useState<XYPosition | null>(null);

  const handleRootContext = (e: React.MouseEvent<HTMLDivElement>) => {
    setPosition(rf.project({ x: e.clientX, y: e.clientY }));
    e.preventDefault();
    ctxManager.next('ctxRoot', contextMenuRef.current);
    contextMenuRef.current?.show(e);
  };

  const onAddSystem = () => {
    outCommand({ type: OutCommand.manualAddSystem, data: { coordinates: position } });
  };

  return {
    handleRootContext,

    contextMenuRef,
    onAddSystem,
  };
};
