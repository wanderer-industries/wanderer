import React, { RefObject } from 'react';
import { ContextMenu } from 'primereact/contextmenu';
import { PingType, SolarSystemRawType } from '@/hooks/Mapper/types';
import { useContextMenuSystemItems } from '@/hooks/Mapper/components/contexts/ContextMenuSystem/useContextMenuSystemItems.tsx';
import { WaypointSetContextHandler } from '@/hooks/Mapper/components/contexts/types.ts';

export interface ContextMenuSystemProps {
  hubs: string[];
  userHubs: string[];
  contextMenuRef: RefObject<ContextMenu>;
  systemId: string | undefined;
  systems: SolarSystemRawType[];
  onDeleteSystem(): void;
  onLockToggle(): void;
  onOpenSettings(): void;
  onHubToggle(): void;
  onUserHubToggle(): void;
  onSystemTag(val?: string): void;
  onSystemStatus(val: number): void;
  onSystemLabels(val: string): void;
  onCustomLabelDialog(): void;
  onTogglePing(type: PingType, solar_system_id: string, ping_id: string | undefined, hasPing: boolean): void;
  onWaypointSet: WaypointSetContextHandler;
}

export const ContextMenuSystem: React.FC<ContextMenuSystemProps> = ({ contextMenuRef, ...props }) => {
  const items = useContextMenuSystemItems(props);

  return (
    <>
      <ContextMenu className="min-w-[200px]" model={items} ref={contextMenuRef} breakpoint="767px" />
    </>
  );
};
