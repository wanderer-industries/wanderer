import { Node } from 'reactflow';
import { useCallback, useMemo, useRef, useState } from 'react';
import { ContextMenu } from 'primereact/contextmenu';
import { SolarSystemRawType } from '@/hooks/Mapper/types';
import { ctxManager } from '@/hooks/Mapper/utils/contextManager.ts';
import { NodeSelectionMouseHandler } from '@/hooks/Mapper/components/contexts/types.ts';
import { useDeleteSystems } from '@/hooks/Mapper/components/contexts/hooks';
import { useMapRootState } from '@/hooks/Mapper/mapRootProvider';
import { encodeJsonToUriBase64 } from '@/hooks/Mapper/utils';
import { useToast } from '@/hooks/Mapper/ToastProvider.tsx';

export const useContextMenuSystemMultipleHandlers = () => {
  const {
    data: { pings, connections },
  } = useMapRootState();

  const { show } = useToast();

  const contextMenuRef = useRef<ContextMenu | null>(null);
  const [systems, setSystems] = useState<Node<SolarSystemRawType>[]>();

  const { deleteSystems } = useDeleteSystems();
  const ping = useMemo(() => (pings.length === 1 ? pings[0] : undefined), [pings]);
  const refVars = useRef({ systems, ping, connections, deleteSystems });
  refVars.current = { systems, ping, connections, deleteSystems };

  const handleSystemMultipleContext = useCallback<NodeSelectionMouseHandler>((ev, systems_) => {
    setSystems(systems_);
    ev.preventDefault();
    ctxManager.next('ctxSysMult', contextMenuRef.current);
    contextMenuRef.current?.show(ev);
  }, []);

  const onDeleteSystems = useCallback(() => {
    const { systems, ping, deleteSystems } = refVars.current;

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
  }, []);

  const onCopySystems = useCallback(async () => {
    const { systems, connections } = refVars.current;
    if (!systems) {
      return;
    }

    const connectionToCopy = connections.filter(
      c => systems.filter(s => [c.target, c.source].includes(s.id)).length == 2,
    );

    await navigator.clipboard.writeText(
      encodeJsonToUriBase64({ systems: systems.map(x => x.data), connections: connectionToCopy }),
    );

    show({
      severity: 'success',
      summary: 'Copied to clipboard',
      detail: `Successfully copied to clipboard - [${systems.length}] systems and [${connectionToCopy.length}] connections`,
      life: 3000,
    });
  }, [show]);

  return {
    handleSystemMultipleContext,
    contextMenuRef,
    onDeleteSystems,
    onCopySystems,
  };
};
