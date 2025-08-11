import { Node } from 'reactflow';
import { useCallback, useMemo, useRef, useState } from 'react';
import { ContextMenu } from 'primereact/contextmenu';
import { SolarSystemRawType } from '@/hooks/Mapper/types';
import { ctxManager } from '@/hooks/Mapper/utils/contextManager.ts';
import { NodeSelectionMouseHandler } from '@/hooks/Mapper/components/contexts/types.ts';
import { useDeleteSystems } from '@/hooks/Mapper/components/contexts/hooks';
import { useMapRootState } from '@/hooks/Mapper/mapRootProvider';

export const useContextMenuSystemMultipleHandlers = () => {
  const {
    data: { pings },
  } = useMapRootState();

  const contextMenuRef = useRef<ContextMenu | null>(null);
  const [systems, setSystems] = useState<Node<SolarSystemRawType>[]>();

  const { deleteSystems } = useDeleteSystems();

  const ping = useMemo(() => (pings.length === 1 ? pings[0] : undefined), [pings]);

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

    const sysToDel = systems
      .filter(x => !x.data.locked)
      .filter(x => x.id !== ping?.solar_system_id)
      .map(x => x.id);

    if (sysToDel.length === 0) {
      return;
    }

    deleteSystems(sysToDel);
  }, [deleteSystems, systems, ping]);

  return {
    handleSystemMultipleContext,
    contextMenuRef,
    onDeleteSystems,
  };
};
