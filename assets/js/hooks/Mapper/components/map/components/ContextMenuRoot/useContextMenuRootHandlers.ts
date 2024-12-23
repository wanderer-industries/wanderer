import { useReactFlow, XYPosition } from 'reactflow';
import React, { useCallback, useRef, useState } from 'react';
import { ContextMenu } from 'primereact/contextmenu';
import { ctxManager } from '@/hooks/Mapper/utils/contextManager.ts';
import { OnMapAddSystemCallback } from '@/hooks/Mapper/components/map/map.types.ts';

type UseContextMenuRootHandlers = {
  onAddSystem?: OnMapAddSystemCallback;
};

export const useContextMenuRootHandlers = ({ onAddSystem }: UseContextMenuRootHandlers = {}) => {
  const rf = useReactFlow();
  const contextMenuRef = useRef<ContextMenu | null>(null);
  const [position, setPosition] = useState<XYPosition | null>(null);

  const handleRootContext = (e: React.MouseEvent<HTMLDivElement>) => {
    setPosition(rf.project({ x: e.clientX, y: e.clientY }));
    e.preventDefault();
    ctxManager.next('ctxRoot', contextMenuRef.current);
    contextMenuRef.current?.show(e);
  };

  const ref = useRef({ onAddSystem, position });
  ref.current = { onAddSystem, position };

  const onAddSystemCallback = useCallback(() => {
    ref.current.onAddSystem?.({ coordinates: position });
  }, [position]);

  return {
    handleRootContext,

    contextMenuRef,
    onAddSystem: onAddSystemCallback,
  };
};
