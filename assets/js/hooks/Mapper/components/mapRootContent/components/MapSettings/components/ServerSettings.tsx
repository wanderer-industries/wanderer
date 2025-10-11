import { useMapRootState } from '@/hooks/Mapper/mapRootProvider';
import { useCallback, useEffect, useRef, useState } from 'react';
import { Toast } from 'primereact/toast';
import { OutCommand } from '@/hooks/Mapper/types';
import { createDefaultStoredSettings } from '@/hooks/Mapper/mapRootProvider/helpers/createDefaultStoredSettings.ts';
import { callToastSuccess } from '@/hooks/Mapper/helpers';
import { ConfirmPopup } from 'primereact/confirmpopup';
import { useConfirmPopup } from '@/hooks/Mapper/hooks';
import { RemoteAdminSettingsResponse } from '@/hooks/Mapper/mapRootProvider/types.ts';
import { applyMigrations } from '@/hooks/Mapper/mapRootProvider/migrations';
import { WdButton } from '@/hooks/Mapper/components/ui-kit';

export const ServerSettings = () => {
  const {
    storedSettings: { applySettings },
    outCommand,
  } = useMapRootState();

  const [hasSettings, setHasSettings] = useState(false);
  const { cfShow, cfHide, cfVisible, cfRef } = useConfirmPopup();
  const toast = useRef<Toast | null>(null);

  const handleSync = useCallback(async () => {
    let res: RemoteAdminSettingsResponse | undefined;
    try {
      res = await outCommand({ type: OutCommand.getDefaultSettings, data: null });
    } catch (error) {
      // do nothing
    }

    if (res?.default_settings == null) {
      applySettings(createDefaultStoredSettings());
      return;
    }

    try {
      //INFO: INSTEAD CHECK WE WILL TRY TO APPLY MIGRATION
      applySettings(applyMigrations(JSON.parse(res.default_settings)) || createDefaultStoredSettings());
      callToastSuccess(toast.current, 'Settings synchronized successfully');
    } catch (error) {
      applySettings(createDefaultStoredSettings());
    }
  }, [applySettings, outCommand]);

  useEffect(() => {
    const load = async () => {
      let res: RemoteAdminSettingsResponse | undefined;
      try {
        res = await outCommand({ type: OutCommand.getDefaultSettings, data: null });
      } catch (error) {
        // do nothing
      }

      if (res?.default_settings == null) {
        return;
      }

      setHasSettings(true);
    };

    load();
  }, [outCommand]);

  return (
    <div className="w-full h-full flex flex-col gap-5">
      <div className="flex flex-col gap-1">
        <div>
          <WdButton
            // @ts-ignore
            ref={cfRef}
            onClick={cfShow}
            icon="pi pi-file-import"
            size="small"
            severity="warning"
            label="Sync with Default Settings"
            className="py-[4px]"
            disabled={!hasSettings}
          />
        </div>
        {!hasSettings && (
          <span className="text-red-500/70 text-[12px]">*Default settings was not set by map administrator.</span>
        )}
        <span className="text-stone-500 text-[12px]">*Will apply admin settings which set as Default for map.</span>
      </div>

      <Toast ref={toast} />

      <ConfirmPopup
        target={cfRef.current}
        visible={cfVisible}
        onHide={cfHide}
        message="You lost your current settings. Sure?."
        icon="pi pi-exclamation-triangle"
        accept={handleSync}
      />
    </div>
  );
};
