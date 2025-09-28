import { useMapRootState } from '@/hooks/Mapper/mapRootProvider';
import { useCallback, useRef, useState } from 'react';
import { Toast } from 'primereact/toast';
import { OutCommand } from '@/hooks/Mapper/types';
import { Divider } from 'primereact/divider';
import { callToastError, callToastSuccess, callToastWarn } from '@/hooks/Mapper/helpers';
import { WdButton } from '@/hooks/Mapper/components/ui-kit';

type SaveDefaultSettingsReturn = { success: boolean; error: string };

export const DefaultSettings = () => {
  const {
    outCommand,
    storedSettings: { getSettingsForExport },
    data: { userPermissions },
  } = useMapRootState();

  const [loading, setLoading] = useState(false);
  const toast = useRef<Toast | null>(null);

  const refVars = useRef({ getSettingsForExport, outCommand });
  refVars.current = { getSettingsForExport, outCommand };

  const handleSaveAsDefault = useCallback(async () => {
    const settings = refVars.current.getSettingsForExport();
    if (!settings) {
      callToastWarn(toast.current, 'No settings to save');
      return;
    }

    setLoading(true);

    let response: SaveDefaultSettingsReturn;
    try {
      response = await refVars.current.outCommand({
        type: OutCommand.saveDefaultSettings,
        data: { settings },
      });
    } catch (error) {
      console.error('Save default settings error:', error);
      callToastError(toast.current, 'Failed to save default settings');
      setLoading(false);
      return;
    }

    if (response.success) {
      callToastSuccess(toast.current, 'Default settings saved successfully');
      setLoading(false);
      return;
    }

    callToastError(toast.current, response.error || 'Failed to save default settings');
    setLoading(false);
  }, []);

  if (!userPermissions?.admin_map) {
    return null;
  }

  return (
    <>
      <Divider />
      <div className="w-full h-full flex flex-col gap-5">
        <h3 className="text-lg font-semibold">Default Settings (Admin Only)</h3>

        <div className="flex flex-col gap-1">
          <div>
            <WdButton
              onClick={handleSaveAsDefault}
              icon="pi pi-save"
              size="small"
              severity="danger"
              label="Save as Map Default"
              className="py-[4px]"
              loading={loading}
              disabled={loading}
            />
          </div>

          <span className="text-stone-500 text-[12px]">
            *Will save your current settings as the default for all new users of this map. This action will overwrite
            any existing default settings.
          </span>
        </div>

        <Toast ref={toast} />
      </div>
    </>
  );
};
