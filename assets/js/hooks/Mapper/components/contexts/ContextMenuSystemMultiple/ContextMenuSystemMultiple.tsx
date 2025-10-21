import React, { RefObject, useMemo } from 'react';
import { ContextMenu } from 'primereact/contextmenu';
import { PrimeIcons } from 'primereact/api';
import { MenuItem } from 'primereact/menuitem';
import { checkPermissions } from '@/hooks/Mapper/components/map/helpers';
import { useMapRootState } from '@/hooks/Mapper/mapRootProvider';
import { MenuItemWithInfo, WdMenuItem } from '@/hooks/Mapper/components/ui-kit';
import clsx from 'clsx';

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
  const {
    data: { options, userPermissions },
  } = useMapRootState();

  const items: MenuItem[] = useMemo(() => {
    const allowCopy = checkPermissions(userPermissions, options.allowed_copy_for);
    return [
      {
        label: 'Delete',
        icon: clsx(PrimeIcons.TRASH, 'text-red-400'),
        command: onDeleteSystems,
      },
      { separator: true },
      {
        label: 'Copy',
        icon: PrimeIcons.COPY,
        command: onCopySystems,
        disabled: !allowCopy,
        template: () => {
          if (allowCopy) {
            return <WdMenuItem icon="pi pi-copy">Copy</WdMenuItem>;
          }

          return (
            <MenuItemWithInfo
              infoTitle="Action is blocked because you don’t have permission to Copy."
              infoClass={clsx(PrimeIcons.QUESTION_CIRCLE, 'text-stone-500 mr-[12px]')}
              tooltipWrapperClassName="flex"
            >
              <WdMenuItem disabled icon="pi pi-copy">
                Copy
              </WdMenuItem>
            </MenuItemWithInfo>
          );
        },
      },
    ];
  }, [onCopySystems, onDeleteSystems, options, userPermissions]);

  return (
    <>
      <ContextMenu model={items} ref={contextMenuRef} breakpoint="767px" />
    </>
  );
};
