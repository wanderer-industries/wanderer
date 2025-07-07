import { Dialog } from 'primereact/dialog';
import { Button } from 'primereact/button';
import { ConfirmPopup } from 'primereact/confirmpopup';
import { useCallback, useRef, useState } from 'react';
import { MapUserSettings } from '@/hooks/Mapper/mapRootProvider/types.ts';
import {
  DEFAULT_KILLS_WIDGET_SETTINGS,
  DEFAULT_ON_THE_MAP_SETTINGS,
  DEFAULT_ROUTES_SETTINGS,
  DEFAULT_WIDGET_LOCAL_SETTINGS,
  getDefaultWidgetProps,
  STORED_INTERFACE_DEFAULT_VALUES,
} from '@/hooks/Mapper/mapRootProvider/constants.ts';
import { DEFAULT_SIGNATURE_SETTINGS } from '@/hooks/Mapper/constants/signatures.ts';
import { Toast } from 'primereact/toast';
import { useMapRootState } from '@/hooks/Mapper/mapRootProvider';
import { saveTextFile } from '@/hooks/Mapper/utils';

const createSettings = function <T>(lsSettings: string | null, defaultValues: T) {
  return {
    version: -1,
    settings: lsSettings ? JSON.parse(lsSettings) : defaultValues,
  };
};

export const OldSettingsDialog = () => {
  const cpRemoveBtnRef = useRef<HTMLElement>();
  const [cpRemoveVisible, setCpRemoveVisible] = useState(false);
  const handleShowCP = useCallback(() => setCpRemoveVisible(true), []);
  const handleHideCP = useCallback(() => setCpRemoveVisible(false), []);
  const toast = useRef<Toast | null>(null);

  const {
    storedSettings: { checkOldSettings },
    data: { map_slug },
  } = useMapRootState();

  const handleExport = useCallback(
    async (asFile?: boolean) => {
      const interfaceSettings = localStorage.getItem('window:interface:settings');
      const widgetRoutes = localStorage.getItem('window:interface:routes');
      const widgetLocal = localStorage.getItem('window:interface:local');
      const widgetKills = localStorage.getItem('kills:widget:settings');
      const onTheMapOld = localStorage.getItem('window:onTheMap:settings');
      const widgetsOld = localStorage.getItem('windows:settings:v2');
      const signatures = localStorage.getItem('wanderer_system_signature_settings_v6_5');

      const out: MapUserSettings = {
        killsWidget: createSettings(widgetKills, DEFAULT_KILLS_WIDGET_SETTINGS),
        localWidget: createSettings(widgetLocal, DEFAULT_WIDGET_LOCAL_SETTINGS),
        widgets: createSettings(widgetsOld, getDefaultWidgetProps()),
        routes: createSettings(widgetRoutes, DEFAULT_ROUTES_SETTINGS),
        onTheMap: createSettings(onTheMapOld, DEFAULT_ON_THE_MAP_SETTINGS),
        signaturesWidget: createSettings(signatures, DEFAULT_SIGNATURE_SETTINGS),
        interface: createSettings(interfaceSettings, STORED_INTERFACE_DEFAULT_VALUES),
      };

      if (asFile) {
        if (!out) {
          return;
        }

        try {
          saveTextFile(`map_settings_${map_slug}.json`, JSON.stringify(out));

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
          return;
        }

        return;
      }

      try {
        await navigator.clipboard.writeText(JSON.stringify(out));

        toast.current?.show({
          severity: 'success',
          summary: 'Export to clipboard',
          detail: 'Map settings was export successfully.',
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
    },
    [map_slug],
  );

  const handleExportClipboard = useCallback(async () => {
    await handleExport();
  }, [handleExport]);

  const handleExportAsFile = useCallback(async () => {
    await handleExport(true);
  }, [handleExport]);

  const handleProceed = useCallback(() => {
    localStorage.removeItem('window:interface:settings');
    localStorage.removeItem('window:interface:routes');
    localStorage.removeItem('window:interface:local');
    localStorage.removeItem('kills:widget:settings');
    localStorage.removeItem('window:onTheMap:settings');
    localStorage.removeItem('windows:settings:v2');
    localStorage.removeItem('wanderer_system_signature_settings_v6_5');

    checkOldSettings();
  }, [checkOldSettings]);

  return (
    <>
      <Dialog
        header={
          <div className="dialog-header">
            <span className="pointer-events-none">Old settings detected!</span>
          </div>
        }
        draggable={false}
        resizable={false}
        closable={false}
        visible
        onHide={() => null}
        className="w-[640px] h-[400px] text-text-color min-h-0"
        footer={
          <div className="flex items-center justify-end">
            <Button
              // @ts-ignore
              ref={cpRemoveBtnRef}
              onClick={handleShowCP}
              icon="pi pi-exclamation-triangle"
              size="small"
              severity="warning"
              label="Proceed"
            />
          </div>
        }
      >
        <div className="w-full h-full flex flex-col gap-1 items-center justify-center text-stone-400 text-[15px]">
          <span>
            We detected <span className="text-orange-400">deprecated</span> settings saved in your browser.
          </span>
          <span>
            Now we will give you ability to make <span className="text-orange-400">export</span> your old settings.
          </span>
          <span>
            After click: all settings will saved in your <span className="text-orange-400">clipboard</span>.
          </span>
          <span>
            Then you need to go into <span className="text-orange-400">Map Settings</span> and click{' '}
            <span className="text-orange-400">Import from clipboard</span>
          </span>
          <div className="h-[30px]"></div>

          <div className="flex items-center gap-3">
            <Button
              onClick={handleExportClipboard}
              icon="pi pi-copy"
              size="small"
              severity="info"
              label="Export to Clipboard"
            />

            <Button
              onClick={handleExportAsFile}
              icon="pi pi-download"
              size="small"
              severity="info"
              label="Export as File"
            />
          </div>

          <span className="text-stone-600 text-[12px]">*You will see this dialog until click Export.</span>
        </div>
      </Dialog>

      <ConfirmPopup
        target={cpRemoveBtnRef.current}
        visible={cpRemoveVisible}
        onHide={handleHideCP}
        message="After click dialog will disappear. Ready?"
        icon="pi pi-exclamation-triangle"
        accept={handleProceed}
      />

      <Toast ref={toast} />
    </>
  );
};
