import { useMapRootState } from '@/hooks/Mapper/mapRootProvider';
import { useCallback, useRef, useState } from 'react';
import { Toast } from 'primereact/toast';
import { Button } from 'primereact/button';
import { OutCommand } from '@/hooks/Mapper/types';
import { Divider } from 'primereact/divider';

export const DefaultSettings = () => {
  const mapRootState = useMapRootState();
  const { getSettingsForExport } = mapRootState.storedSettings || {};
  const { userPermissions } = mapRootState.data || {};
  const { outCommand } = mapRootState;

  const [loading, setLoading] = useState(false);
  const toast = useRef<Toast | null>(null);

  const handleSaveAsDefault = useCallback(async () => {
    if (!getSettingsForExport) {
      console.error('DefaultSettings: getSettingsForExport is not available');
      return;
    }
    
    const settings = getSettingsForExport();
    if (!settings) {
      toast.current?.show({
        severity: 'warn',
        summary: 'Warning',
        detail: 'No settings to save',
        life: 3000,
      });
      return;
    }

    try {
      if (!outCommand) {
        console.error('DefaultSettings: outCommand is not available');
        return;
      }
      
      setLoading(true);
      const response = await outCommand({
        type: OutCommand.saveDefaultSettings,
        data: { settings },
      });

      if (response.success) {
        toast.current?.show({
          severity: 'success',
          summary: 'Success',
          detail: 'Default settings saved successfully',
          life: 3000,
        });
      } else {
        toast.current?.show({
          severity: 'error',
          summary: 'Error',
          detail: response.error || 'Failed to save default settings',
          life: 5000,
        });
      }
    } catch (error) {
      console.error('Save default settings error:', error);
      toast.current?.show({
        severity: 'error',
        summary: 'Error',
        detail: 'Failed to save default settings',
        life: 3000,
      });
    } finally {
      setLoading(false);
    }
  }, [getSettingsForExport, outCommand]);

  // Only show for map admins
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
            <Button
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
            *Will save your current settings as the default for all new users of this map. This action will overwrite any existing default settings.
          </span>
        </div>

        <Toast ref={toast} />
      </div>
    </>
  );
};