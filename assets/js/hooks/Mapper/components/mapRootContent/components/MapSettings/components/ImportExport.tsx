import { useMapRootState } from '@/hooks/Mapper/mapRootProvider';
import { useCallback, useMemo, useRef, useState } from 'react';
import { Toast } from 'primereact/toast';
import { parseMapUserSettings } from '@/hooks/Mapper/components/helpers';
import { saveTextFile } from '@/hooks/Mapper/utils/saveToFile.ts';
import { SplitButton } from 'primereact/splitbutton';
import { loadTextFile } from '@/hooks/Mapper/utils';
import { DefaultSettings } from './DefaultSettings';
import { Button } from 'primereact/button';
import { OutCommand } from '@/hooks/Mapper/types';
import { ConfirmDialog } from 'primereact/confirmdialog';

// Helper function to validate map settings structure
const validateMapSettings = (settings: any): void => {
  if (!settings || typeof settings !== 'object') {
    throw new Error('Invalid settings format');
  }
  
  // Check for required top-level properties
  const requiredProps = ['killsWidget', 'localWidget', 'widgets', 'routes', 'onTheMap', 'signaturesWidget', 'interface'];
  const hasRequiredProps = requiredProps.every(prop => prop in settings);
  
  if (!hasRequiredProps) {
    throw new Error('Settings missing required properties');
  }
};

export const ImportExport = () => {
  const {
    storedSettings: { getSettingsForExport, applySettings },
    data: { map_slug },
    outCommand,
  } = useMapRootState();
  
  const [showResetConfirm, setShowResetConfirm] = useState(false);
  const [resetting, setResetting] = useState(false);

  const toast = useRef<Toast | null>(null);

  const handleImportFromClipboard = useCallback(async () => {
    const text = await navigator.clipboard.readText();

    if (text == null || text == '') {
      return;
    }

    try {
      const parsed = parseMapUserSettings(text);
      validateMapSettings(parsed);
      
      if (applySettings(parsed)) {
        toast.current?.show({
          severity: 'success',
          summary: 'Import',
          detail: 'Map settings was imported successfully.',
          life: 3000,
        });

        setTimeout(() => {
          window.dispatchEvent(new Event('resize'));
        }, 100);
        return;
      }

      toast.current?.show({
        severity: 'warn',
        summary: 'Warning',
        detail: 'Settings already imported. Or something went wrong.',
        life: 3000,
      });
    } catch (error) {
      console.error(`Import from clipboard Error: `, error);

      toast.current?.show({
        severity: 'error',
        summary: 'Error',
        detail: 'Some error occurred on import from Clipboard, check console log.',
        life: 3000,
      });
    }
  }, [applySettings]);

  const handleImportFromFile = useCallback(async () => {
    try {
      const text = await loadTextFile();

      const parsed = parseMapUserSettings(text);
      validateMapSettings(parsed);
      
      if (applySettings(parsed)) {
        toast.current?.show({
          severity: 'success',
          summary: 'Import',
          detail: 'Map settings was imported successfully.',
          life: 3000,
        });
        return;
      }

      toast.current?.show({
        severity: 'warn',
        summary: 'Warning',
        detail: 'Settings already imported. Or something went wrong.',
        life: 3000,
      });
    } catch (error) {
      console.error(`Import from file Error: `, error);

      toast.current?.show({
        severity: 'error',
        summary: 'Error',
        detail: 'Some error occurred on import from File, check console log.',
        life: 3000,
      });
    }
  }, [applySettings]);

  const handleExportToClipboard = useCallback(async () => {
    const settings = getSettingsForExport();
    if (!settings) {
      return;
    }

    try {
      await navigator.clipboard.writeText(settings);
      toast.current?.show({
        severity: 'success',
        summary: 'Export',
        detail: 'Map settings copied into clipboard',
        life: 3000,
      });
    } catch (error) {
      console.error(`Export to clipboard Error: `, error);
      toast.current?.show({
        severity: 'error',
        summary: 'Error',
        detail: 'Some error occurred on copying to clipboard, check console log.',
        life: 3000,
      });
    }
  }, [getSettingsForExport]);

  const handleExportToFile = useCallback(async () => {
    const settings = getSettingsForExport();
    if (!settings) {
      return;
    }

    try {
      saveTextFile(`map_settings_${map_slug}.json`, settings);

      toast.current?.show({
        severity: 'success',
        summary: 'Export to File',
        detail: 'Map settings successfully saved to file',
        life: 3000,
      });
    } catch (error) {
      console.error(`Export to cliboard Error: `, error);
      toast.current?.show({
        severity: 'error',
        summary: 'Error',
        detail: 'Some error occurred on saving to file, check console log.',
        life: 3000,
      });
    }
  }, [getSettingsForExport, map_slug]);

  const importItems = useMemo(
    () => [
      {
        label: 'Import from File',
        icon: 'pi pi-file-import',
        command: handleImportFromFile,
      },
    ],
    [handleImportFromFile],
  );

  const exportItems = useMemo(
    () => [
      {
        label: 'Export as File',
        icon: 'pi pi-file-export',
        command: handleExportToFile,
      },
    ],
    [handleExportToFile],
  );

  const handleResetToDefaults = useCallback(async () => {
    try {
      setResetting(true);
      
      // First try to get default settings from server
      const response = await outCommand({
        type: OutCommand.getDefaultSettings,
        data: null,
      });

      if (response?.default_settings) {
        // Apply server default settings
        try {
          const parsed = parseMapUserSettings(response.default_settings);
          validateMapSettings(parsed);
          
          if (applySettings(parsed)) {
            toast.current?.show({
              severity: 'success',
              summary: 'Reset Successful',
              detail: 'Settings have been reset to map defaults.',
              life: 3000,
            });
            
            setTimeout(() => {
              window.dispatchEvent(new Event('resize'));
            }, 100);
          } else {
            toast.current?.show({
              severity: 'warn',
              summary: 'Warning',
              detail: 'Settings are already at default values.',
              life: 3000,
            });
          }
        } catch (error) {
          console.error('Invalid default settings:', error);
          toast.current?.show({
            severity: 'error',
            summary: 'Error',
            detail: 'Default settings are invalid. Using system defaults instead.',
            life: 3000,
          });
          
          // Fall back to clearing settings
          const currentSettings = localStorage.getItem('map-user-settings');
          if (currentSettings) {
            const parsed = JSON.parse(currentSettings);
            delete parsed[map_slug];
            localStorage.setItem('map-user-settings', JSON.stringify(parsed));
            window.location.reload();
          }
        }
      } else {
        // No server defaults, reset to hardcoded defaults
        // Clear the settings for this map to trigger default loading
        const currentSettings = localStorage.getItem('map-user-settings');
        if (currentSettings) {
          const parsed = JSON.parse(currentSettings);
          delete parsed[map_slug];
          localStorage.setItem('map-user-settings', JSON.stringify(parsed));
          
          // Force reload to apply defaults
          window.location.reload();
        }
      }
    } catch (error) {
      console.error('Reset to defaults error:', error);
      toast.current?.show({
        severity: 'error',
        summary: 'Error',
        detail: 'Failed to reset settings to defaults.',
        life: 3000,
      });
    } finally {
      setResetting(false);
      setShowResetConfirm(false);
    }
  }, [applySettings, map_slug, outCommand]);

  return (
    <div className="w-full h-full flex flex-col gap-5">
      <div className="flex flex-col gap-1">
        <div>
          <SplitButton
            onClick={handleImportFromClipboard}
            icon="pi pi-download"
            size="small"
            severity="warning"
            label="Import from Clipboard"
            className="py-[4px]"
            model={importItems}
          />
        </div>

        <span className="text-stone-500 text-[12px]">
          *Will read map settings from clipboard. Be careful it could overwrite current settings.
        </span>
      </div>

      <div className="flex flex-col gap-1">
        <div>
          <SplitButton
            onClick={handleExportToClipboard}
            icon="pi pi-upload"
            size="small"
            label="Export to Clipboard"
            className="py-[4px]"
            model={exportItems}
          />
        </div>

        <span className="text-stone-500 text-[12px]">*Will save map settings to clipboard.</span>
      </div>

      <div className="flex flex-col gap-1">
        <div>
          <Button
            onClick={() => setShowResetConfirm(true)}
            icon="pi pi-refresh"
            size="small"
            severity="danger"
            label="Reset to Defaults"
            className="py-[4px]"
            loading={resetting}
            disabled={resetting}
          />
        </div>

        <span className="text-stone-500 text-[12px]">
          *Will reset all your map settings to the default values. This action cannot be undone.
        </span>
      </div>

      <DefaultSettings />
      
      <ConfirmDialog
        visible={showResetConfirm}
        onHide={() => setShowResetConfirm(false)}
        message="Are you sure you want to reset all your settings to the default values? This action cannot be undone."
        header="Reset Settings Confirmation"
        icon="pi pi-exclamation-triangle"
        accept={handleResetToDefaults}
        reject={() => setShowResetConfirm(false)}
        acceptLabel="Yes, Reset"
        rejectLabel="Cancel"
        acceptClassName="p-button-danger"
      />
      
      <Toast ref={toast} />
    </div>
  );
};
