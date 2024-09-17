import { Node } from 'reactflow';
import { useRef, useState } from 'react';
import { ContextMenu } from 'primereact/contextmenu';
import { OutCommand } from '@/hooks/Mapper/types/mapHandlers.ts';
import { SolarSystemRawType } from '@/hooks/Mapper/types';
import { ctxManager } from '@/hooks/Mapper/utils/contextManager.ts';
import { useMapRootState } from '@/hooks/Mapper/mapRootProvider';
import { NodeSelectionMouseHandler } from '@/hooks/Mapper/components/contexts/types.ts';

export const useContextMenuSystemMultipleHandlers = () => {
  const contextMenuRef = useRef<ContextMenu | null>(null);
  const { outCommand } = useMapRootState();
  const [systems, setSystems] = useState<Node<SolarSystemRawType>[]>();

  const handleSystemMultipleContext: NodeSelectionMouseHandler = (ev, systems_) => {
    setSystems(systems_);
    ev.preventDefault();
    ctxManager.next('ctxSysMult', contextMenuRef.current);
    contextMenuRef.current?.show(ev);
  };

  const onDeleteSystems = () => {
    if (!systems) {
      return;
    }

    const sysToDel = systems.filter(x => !x.data.locked).map(x => x.id);
    if (sysToDel.length === 0) {
      return;
    }

    outCommand({ type: OutCommand.deleteSystems, data: sysToDel });
  };

  return {
    handleSystemMultipleContext,

    contextMenuRef,
    onDeleteSystems,
  };
};
