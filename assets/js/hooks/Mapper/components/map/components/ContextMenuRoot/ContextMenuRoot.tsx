import React, { RefObject, useMemo } from 'react';
import { ContextMenu } from 'primereact/contextmenu';
import { PrimeIcons } from 'primereact/api';
import { MenuItem } from 'primereact/menuitem';
import { PasteSystemsAndConnections } from '@/hooks/Mapper/components/map/components';

export interface ContextMenuRootProps {
  contextMenuRef: RefObject<ContextMenu>;
  pasteSystemsAndConnections: PasteSystemsAndConnections | undefined;
  onAddSystem(): void;
  onPasteSystemsAnsConnections(): void;
}

export const ContextMenuRoot: React.FC<ContextMenuRootProps> = ({
  contextMenuRef,
  onAddSystem,
  onPasteSystemsAnsConnections,
  pasteSystemsAndConnections,
}) => {
  const items: MenuItem[] = useMemo(() => {
    return [
      {
        label: 'Add System',
        icon: PrimeIcons.PLUS,
        command: onAddSystem,
      },
      ...(pasteSystemsAndConnections != null
        ? [
            {
              label: 'Paste',
              icon: 'pi pi-clipboard',
              command: onPasteSystemsAnsConnections,
            },
          ]
        : []),
    ];
  }, [onAddSystem, onPasteSystemsAnsConnections, pasteSystemsAndConnections]);

  return (
    <>
      <ContextMenu model={items} ref={contextMenuRef} breakpoint="767px" />
    </>
  );
};
