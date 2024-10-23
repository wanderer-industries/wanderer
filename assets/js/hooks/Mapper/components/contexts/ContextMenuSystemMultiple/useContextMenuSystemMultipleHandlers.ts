import { Node } from 'reactflow';
import { useCallback, useRef, useState } from 'react';
import { ContextMenu } from 'primereact/contextmenu';
import { SolarSystemRawType } from '@/hooks/Mapper/types';
import { ctxManager } from '@/hooks/Mapper/utils/contextManager.ts';
import { NodeSelectionMouseHandler } from '@/hooks/Mapper/components/contexts/types.ts';
import { useDeleteSystems } from '@/hooks/Mapper/components/contexts/hooks';

export const useContextMenuSystemMultipleHandlers = () => {
  const contextMenuRef = useRef<ContextMenu | null>(null);
  const [systems, setSystems] = useState<Node<SolarSystemRawType>[]>();

  const { deleteSystems } = useDeleteSystems();

  const handleSystemMultipleContext: NodeSelectionMouseHandler = (ev, systems_) => {
    setSystems(systems_);
    ev.preventDefault();
    ctxManager.next('ctxSysMult', contextMenuRef.current);
    contextMenuRef.current?.show(ev);
  };

  const onDeleteSystems = useCallback(() => {
    if (!systems) {
      return;
    }

    const sysToDel = systems.filter(x => !x.data.locked).map(x => x.id);
    if (sysToDel.length === 0) {
      return;
    }

    deleteSystems(sysToDel);
  }, [deleteSystems, systems]);

  return {
    handleSystemMultipleContext,
    contextMenuRef,
    onDeleteSystems,
  };
};
