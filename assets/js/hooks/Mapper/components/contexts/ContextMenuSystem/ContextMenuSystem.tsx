import React, { RefObject } from 'react';
import { ContextMenu } from 'primereact/contextmenu';
import { SolarSystemRawType } from '@/hooks/Mapper/types';
import { useContextMenuSystemItems } from '@/hooks/Mapper/components/contexts/ContextMenuSystem/useContextMenuSystemItems.tsx';
import { WaypointSetContextHandler } from '@/hooks/Mapper/components/contexts/types.ts';

export interface ContextMenuSystemProps {
  hubs: string[];
  contextMenuRef: RefObject<ContextMenu>;
  systemId: string | undefined;
  systems: SolarSystemRawType[];
  onDeleteSystem(): void;
  onLockToggle(): void;
  onOpenSettings(): void;
  onHubToggle(): void;
  onSystemTag(val?: string): void;
  onSystemStatus(val: number): void;
  onSystemLabels(val: string): void;
  onCustomLabelDialog(): void;
  onWaypointSet: WaypointSetContextHandler;
}

export const ContextMenuSystem: React.FC<ContextMenuSystemProps> = ({ contextMenuRef, ...props }) => {
  const items = useContextMenuSystemItems(props);

  return (
    <>
      <ContextMenu model={items} ref={contextMenuRef} breakpoint="767px" />
    </>
  );
};
