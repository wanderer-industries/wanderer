import clsx from 'clsx';

import { SystemSignature } from '@/hooks/Mapper/types';
import { SystemViewStandalone } from '@/hooks/Mapper/components/ui-kit';

export const renderLinkedSystem = (row: SystemSignature) => {
  if (!row.linked_system) {
    return null;
  }

  return (
    <span title={row.linked_system?.solar_system_name}>
      <SystemViewStandalone
        className={clsx('select-none text-center cursor-context-menu')}
        hideRegion
        {...row.linked_system}
      />
    </span>
  );
};
