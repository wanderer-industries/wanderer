import { MigrationStructure } from '@/hooks/Mapper/mapRootProvider/types.ts';
import { STORED_INTERFACE_DEFAULT_VALUES } from '@/hooks/Mapper/mapRootProvider/constants.ts';

export const to_4: MigrationStructure = {
  to: 4,
  up: (prev: any) => {
    let hideBookmarkWarning = false;

    // Check if the old unmanaged setting exists
    const unmanagedSetting = localStorage.getItem('hide_bookmark_warning');
    if (unmanagedSetting) {
      hideBookmarkWarning = unmanagedSetting === 'true';
      localStorage.removeItem('hide_bookmark_warning');
    }

    const interfaceSettings = prev?.interface || {};

    return {
      ...prev,
      interface: {
        ...STORED_INTERFACE_DEFAULT_VALUES,
        ...interfaceSettings,
        // Carry over the unmanaged setting if it's true, or just use what interfaceSettings has
        hideBookmarkWarning: hideBookmarkWarning || interfaceSettings.hideBookmarkWarning || false,
      },
    };
  },
};
