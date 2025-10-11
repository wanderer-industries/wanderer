import { useMapRootState } from '@/hooks/Mapper/mapRootProvider';
import { useCallback, useMemo, useRef } from 'react';
import { Toast } from 'primereact/toast';
import { parseMapUserSettings } from '@/hooks/Mapper/components/helpers';
import { saveTextFile } from '@/hooks/Mapper/utils/saveToFile.ts';
import { SplitButton } from 'primereact/splitbutton';
import { loadTextFile } from '@/hooks/Mapper/utils';
import { applyMigrations } from '@/hooks/Mapper/mapRootProvider/migrations';
import { createDefaultStoredSettings } from '@/hooks/Mapper/mapRootProvider/helpers/createDefaultStoredSettings.ts';

export const ImportExport = () => {
  const {
    storedSettings: { getSettingsForExport, applySettings },
    data: { map_slug },
  } = useMapRootState();

  const toast = useRef<Toast | null>(null);

  const handleImportFromClipboard = useCallback(async () => {
    const text = await navigator.clipboard.readText();

    if (text == null || text == '') {
      return;
    }

    try {
      // INFO: WE NOT SUPPORT MIGRATIONS FOR OLD FILES AND Clipboard
      const parsed = parseMapUserSettings(text);
      if (applySettings(applyMigrations(parsed) || createDefaultStoredSettings())) {
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

      // INFO: WE NOT SUPPORT MIGRATIONS FOR OLD FILES AND Clipboard
      const parsed = parseMapUserSettings(text);
      if (applySettings(applyMigrations(parsed) || createDefaultStoredSettings())) {
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

      <Toast ref={toast} />
    </div>
  );
};
