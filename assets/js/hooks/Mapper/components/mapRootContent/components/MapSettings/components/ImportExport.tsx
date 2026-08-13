import { useMapRootState } from '@/hooks/Mapper/mapRootProvider';
import { useCallback, useMemo, useRef, useState } from 'react';
import { Toast } from 'primereact/toast';
import { parseMapUserSettings } from '@/hooks/Mapper/components/helpers';
import { saveTextFile } from '@/hooks/Mapper/utils/saveToFile.ts';
import { SplitButton } from 'primereact/splitbutton';
import { loadTextFile } from '@/hooks/Mapper/utils';
import { applyMigrations } from '@/hooks/Mapper/mapRootProvider/migrations';
import { createDefaultStoredSettings } from '@/hooks/Mapper/mapRootProvider/helpers/createDefaultStoredSettings.ts';
import { OutCommand } from '@/hooks/Mapper/types';
import { WdButton } from '@/hooks/Mapper/components/ui-kit';
import { Dialog } from 'primereact/dialog';
import { WdCheckbox } from '@/hooks/Mapper/components/ui-kit/WdCheckbox';

type PendingImport = {
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  document: any;
  systems: number;
  connections: number;
  signatures: number;
};

export const ImportExport = () => {
  const {
    storedSettings: { getSettingsForExport, applySettings },
    data: { map_slug },
    outCommand,
  } = useMapRootState();

  const toast = useRef<Toast | null>(null);
  const [mapDataBusy, setMapDataBusy] = useState(false);
  const [includeSignatures, setIncludeSignatures] = useState(true);
  const [pendingImport, setPendingImport] = useState<PendingImport | null>(null);

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

  const handleExportMapData = useCallback(async () => {
    setMapDataBusy(true);

    try {
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      const res: any = await outCommand({
        type: OutCommand.exportMapData,
        data: { include_signatures: includeSignatures },
      });

      if (!res?.data) {
        throw new Error(res?.error ?? 'Empty response');
      }

      const { systems = [], connections = [], signatures = [] } = res.data;

      saveTextFile(`map_${map_slug}_${new Date().toISOString().slice(0, 10)}.json`, JSON.stringify(res.data, null, 2));

      toast.current?.show({
        severity: 'success',
        summary: 'Export map',
        detail: `Saved ${systems.length} systems, ${connections.length} connections, ${signatures.length} signatures.`,
        life: 4000,
      });
    } catch (error) {
      console.error('Export map data Error: ', error);

      toast.current?.show({
        severity: 'error',
        summary: 'Error',
        detail: 'Some error occurred on exporting map data, check console log.',
        life: 3000,
      });
    } finally {
      setMapDataBusy(false);
    }
  }, [includeSignatures, outCommand, map_slug]);

  const handleImportMapData = useCallback(async () => {
    let parsed;

    try {
      parsed = JSON.parse(await loadTextFile());
    } catch (error) {
      console.error('Import map data Error: ', error);

      toast.current?.show({
        severity: 'error',
        summary: 'Error',
        detail: 'Selected file is not a valid map export.',
        life: 3000,
      });
      return;
    }

    // the map is shared and an import cannot be undone, so the counts get confirmed first
    setPendingImport({
      document: parsed,
      systems: Array.isArray(parsed?.systems) ? parsed.systems.length : 0,
      connections: Array.isArray(parsed?.connections) ? parsed.connections.length : 0,
      signatures: Array.isArray(parsed?.signatures) ? parsed.signatures.length : 0,
    });
  }, []);

  const handleConfirmImport = useCallback(async () => {
    if (!pendingImport) {
      return;
    }

    const { document } = pendingImport;

    setPendingImport(null);
    setMapDataBusy(true);

    try {
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      const res: any = await outCommand({
        type: OutCommand.importMapData,
        data: { data: document, include_signatures: includeSignatures },
      });

      if (!res?.result) {
        throw new Error(res?.error ?? 'Empty response');
      }

      const { systems, connections, signatures } = res.result;

      toast.current?.show({
        severity: 'success',
        summary: 'Import map',
        detail:
          systems + connections + signatures === 0
            ? 'Everything in that file was already on the map - nothing was added.'
            : `Added ${systems} systems, ${connections} connections, ${signatures} signatures.`,
        life: 4000,
      });
    } catch (error) {
      console.error('Import map data Error: ', error);

      toast.current?.show({
        severity: 'error',
        summary: 'Error',
        detail: 'Some error occurred on importing map data, check console log.',
        life: 3000,
      });
    } finally {
      setMapDataBusy(false);
    }
  }, [includeSignatures, outCommand, pendingImport]);

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

      <div className="border-b-2 border-dotted border-stone-700/50 h-px" />

      <div className="flex flex-col gap-1">
        <div className="flex gap-2">
          <WdButton
            onClick={handleExportMapData}
            icon="pi pi-cloud-download"
            size="small"
            label="Export map"
            className="py-[4px]"
            disabled={mapDataBusy}
          />
          <WdButton
            onClick={handleImportMapData}
            icon="pi pi-cloud-upload"
            size="small"
            severity="warning"
            label="Import map"
            className="py-[4px]"
            disabled={mapDataBusy}
          />
        </div>

        <WdCheckbox
          label="Include signatures"
          value={includeSignatures}
          onChange={e => setIncludeSignatures(!!e.checked)}
        />

        <span className="text-stone-500 text-[12px]">
          *Map contents - systems, connections and signatures - as a file. Import adds what is missing, systems already
          on the map are left untouched.
        </span>
      </div>

      <Dialog
        header="Import map"
        visible={pendingImport != null}
        draggable={false}
        className="w-[420px]"
        onHide={() => setPendingImport(null)}
      >
        <div className="flex flex-col gap-3">
          <span className="text-stone-200 text-[13px]">
            This adds up to {pendingImport?.systems} systems, {pendingImport?.connections} connections and{' '}
            {includeSignatures ? pendingImport?.signatures : 0} signatures to <b>{map_slug ?? 'this map'}</b>, for
            everyone on the map. Systems already there are left alone, and an import cannot be undone.
          </span>

          <div className="flex justify-end gap-2">
            <WdButton size="small" outlined label="Cancel" onClick={() => setPendingImport(null)} />
            <WdButton size="small" severity="warning" label="Import" onClick={handleConfirmImport} />
          </div>
        </div>
      </Dialog>

      <Toast ref={toast} />
    </div>
  );
};
