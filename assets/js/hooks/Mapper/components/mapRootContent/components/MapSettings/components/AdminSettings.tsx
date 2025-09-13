import { useMapRootState } from '@/hooks/Mapper/mapRootProvider';
import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { Toast } from 'primereact/toast';
import { callToastError, callToastSuccess, callToastWarn } from '@/hooks/Mapper/helpers';
import { OutCommand } from '@/hooks/Mapper/types';
import { ConfirmPopup } from 'primereact/confirmpopup';
import { useConfirmPopup } from '@/hooks/Mapper/hooks';
import { MapUserSettings, RemoteAdminSettingsResponse } from '@/hooks/Mapper/mapRootProvider/types.ts';
import { parseMapUserSettings } from '@/hooks/Mapper/components/helpers';
import fastDeepEqual from 'fast-deep-equal';
import { useDetectSettingsChanged } from '@/hooks/Mapper/components/hooks';
import { WdButton } from '@/hooks/Mapper/components/ui-kit';

export const AdminSettings = () => {
  const {
    storedSettings: { getSettingsForExport },
    outCommand,
  } = useMapRootState();

  const settingsChanged = useDetectSettingsChanged();

  const [currentRemoteSettings, setCurrentRemoteSettings] = useState<MapUserSettings | null>(null);

  const { cfShow, cfHide, cfVisible, cfRef } = useConfirmPopup();
  const toast = useRef<Toast | null>(null);

  const hasSettingsForExport = useMemo(() => !!getSettingsForExport(), [getSettingsForExport]);

  const refVars = useRef({ currentRemoteSettings, getSettingsForExport });
  refVars.current = { currentRemoteSettings, getSettingsForExport };

  useEffect(() => {
    const load = async () => {
      let res: RemoteAdminSettingsResponse | undefined;
      try {
        res = await outCommand({ type: OutCommand.getDefaultSettings, data: null });
      } catch (error) {
        // do nothing
      }

      if (!res || res.default_settings == null) {
        return;
      }

      setCurrentRemoteSettings(parseMapUserSettings(res.default_settings));
    };

    load();
  }, [outCommand]);

  const isDirty = useMemo(() => {
    const { currentRemoteSettings, getSettingsForExport } = refVars.current;
    const localCurrent = parseMapUserSettings(getSettingsForExport());

    return !fastDeepEqual(currentRemoteSettings, localCurrent);
    // eslint-disable-next-line
  }, [settingsChanged, currentRemoteSettings]);

  const handleSync = useCallback(async () => {
    const settings = getSettingsForExport();

    if (!settings) {
      callToastWarn(toast.current, 'No settings to save');

      return;
    }

    let response: { success: boolean } | undefined;

    try {
      response = await outCommand({
        type: OutCommand.saveDefaultSettings,
        data: { settings },
      });
    } catch (err) {
      callToastError(toast.current, 'Something went wrong while saving settings');
      console.error('ERROR: ', err);
      return;
    }

    if (!response || !response.success) {
      callToastError(toast.current, 'Settings not saved - dont not why it');
      return;
    }

    setCurrentRemoteSettings(parseMapUserSettings(settings));

    callToastSuccess(toast.current, 'Settings saved successfully');
  }, [getSettingsForExport, outCommand]);

  return (
    <div className="w-full h-full flex flex-col gap-5">
      <div className="flex flex-col gap-1">
        <div>
          <WdButton
            // @ts-ignore
            ref={cfRef}
            onClick={cfShow}
            icon="pi pi-save"
            size="small"
            severity="danger"
            label="Save as Map Default"
            className="py-[4px]"
            disabled={!hasSettingsForExport || !isDirty}
          />
        </div>

        {!isDirty && <span className="text-red-500/70 text-[12px]">*Local and remote are identical.</span>}

        <span className="text-stone-500 text-[12px]">
          *Will save your current settings as the default for all new users of this map. This action will overwrite any
          existing default settings.
        </span>
      </div>

      <Toast ref={toast} />

      <ConfirmPopup
        target={cfRef.current}
        visible={cfVisible}
        onHide={cfHide}
        message="Your settings will overwrite default. Sure?."
        icon="pi pi-exclamation-triangle"
        accept={handleSync}
      />
    </div>
  );
};
