import React, { RefObject, useMemo } from 'react';
import { ContextMenu } from 'primereact/contextmenu';
import { PrimeIcons } from 'primereact/api';
import { MenuItem } from 'primereact/menuitem';

export interface ContextMenuRootProps {
  contextMenuRef: RefObject<ContextMenu>;
  onAddSystem(): void;
}

export const ContextMenuRoot: React.FC<ContextMenuRootProps> = ({ contextMenuRef, onAddSystem }) => {
  const items: MenuItem[] = useMemo(() => {
    return [
      {
        label: 'Add System',
        icon: PrimeIcons.PLUS,
        command: onAddSystem,
      },
    ];
  }, [onAddSystem]);

  return (
    <>
      <ContextMenu model={items} ref={contextMenuRef} breakpoint="767px" />
    </>
  );
};
