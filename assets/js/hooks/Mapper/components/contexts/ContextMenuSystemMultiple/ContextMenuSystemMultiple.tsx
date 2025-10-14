import React, { RefObject, useMemo } from 'react';
import { ContextMenu } from 'primereact/contextmenu';
import { PrimeIcons } from 'primereact/api';
import { MenuItem } from 'primereact/menuitem';

export interface ContextMenuSystemMultipleProps {
  contextMenuRef: RefObject<ContextMenu>;
  onDeleteSystems(): void;
  onCopySystems(): void;
}

export const ContextMenuSystemMultiple: React.FC<ContextMenuSystemMultipleProps> = ({
  contextMenuRef,
  onDeleteSystems,
  onCopySystems,
}) => {
  const items: MenuItem[] = useMemo(() => {
    return [
      {
        label: 'Copy',
        icon: PrimeIcons.COPY,
        command: onCopySystems,
      },
      {
        label: 'Delete',
        icon: PrimeIcons.TRASH,
        command: onDeleteSystems,
      },
    ];
  }, [onCopySystems, onDeleteSystems]);

  return (
    <>
      <ContextMenu model={items} ref={contextMenuRef} breakpoint="767px" />
    </>
  );
};
