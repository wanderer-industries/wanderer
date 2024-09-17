import React, { RefObject, useMemo } from 'react';
import { ContextMenu } from 'primereact/contextmenu';
import { PrimeIcons } from 'primereact/api';
import { MenuItem } from 'primereact/menuitem';

export interface ContextMenuSystemMultipleProps {
  contextMenuRef: RefObject<ContextMenu>;
  onDeleteSystems(): void;
}

export const ContextMenuSystemMultiple: React.FC<ContextMenuSystemMultipleProps> = ({
  contextMenuRef,
  onDeleteSystems,
}) => {
  const items: MenuItem[] = useMemo(() => {
    return [
      {
        label: 'Delete',
        icon: PrimeIcons.TRASH,
        command: onDeleteSystems,
      },
    ];
  }, [onDeleteSystems]);

  return (
    <>
      <ContextMenu model={items} ref={contextMenuRef} breakpoint="767px" />
    </>
  );
};
