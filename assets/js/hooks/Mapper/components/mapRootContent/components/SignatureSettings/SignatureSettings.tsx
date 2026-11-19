import {
  SignatureGroupContent,
  SignatureGroupSelect,
} from '@/hooks/Mapper/components/mapRootContent/components/SignatureSettings/components';
import { SystemsSettingsProvider } from '@/hooks/Mapper/components/mapRootContent/components/SignatureSettings/Provider.tsx';
import { WdButton } from '@/hooks/Mapper/components/ui-kit';
import { executeSaveSignatureSettings } from '@/hooks/Mapper/helpers/bookmarkFormatHelper.ts';
import { parseSignatureCustomInfo } from '@/hooks/Mapper/helpers/parseSignatureCustomInfo';
import { useMapRootState } from '@/hooks/Mapper/mapRootProvider';
import {
  GetUserSettingsResponse,
  MassState,
  OutCommand,
  SystemSignature,
  TimeStatus,
  UserSettings,
} from '@/hooks/Mapper/types';
import { Dialog } from 'primereact/dialog';
import { InputText } from 'primereact/inputtext';
import { useCallback, useEffect, useState } from 'react';
import { Controller, FormProvider, useForm } from 'react-hook-form';

type SystemSignaturePrepared = Omit<SystemSignature, 'linked_system'> & {
  linked_system: string;
  destType: string;
  k162Type?: string;
  time_status: TimeStatus;
  mass_status: MassState;
};

export interface MapSettingsProps {
  systemId: string;
  show: boolean;
  onHide: () => void;
  signatureData: SystemSignature | undefined;
}

export const SignatureSettings = ({ systemId, show, onHide, signatureData }: MapSettingsProps) => {
  const {
    outCommand,
    data: { systemSignatures, systems, wormholesData, connections },
  } = useMapRootState();

  const signatureForm = useForm<Partial<SystemSignaturePrepared>>({});

  const { setFocus } = signatureForm;

  const handleShow = useCallback(() => {
    setFocus('description');
  }, [setFocus]);

  const [userSettings, setUserSettings] = useState<UserSettings | null>(null);

  useEffect(() => {
    outCommand<GetUserSettingsResponse>({ type: OutCommand.getUserSettings, data: null })
      .then(res => setUserSettings(res?.user_settings ?? null))
      .catch((e: unknown) => console.warn('Failed to fetch user settings', e));
  }, [outCommand]);

  const handleSave = useCallback(
    async (e?: React.FormEvent<HTMLFormElement>) => {
      e?.preventDefault();
      if (!signatureData) {
        return;
      }

      await executeSaveSignatureSettings({
        signatureData,
        formValues: signatureForm.getValues(),
        systemId,
        userSettings,
        systemSignatures,
        systems,
        wormholesData,
        connections,
        outCommand,
      });

      signatureForm.reset();
      onHide();
    },
    [
      signatureData,
      signatureForm,
      outCommand,
      systemId,
      onHide,
      systemSignatures,
      systems,
      wormholesData,
      userSettings,
      connections,
    ],
  );

  useEffect(() => {
    if (!signatureData) {
      signatureForm.reset();
      return;
    }

    const { linked_system, custom_info, ...rest } = signatureData;

    let destType: string | undefined = undefined;
    let k162Type: string | undefined = undefined;
    let time_status = TimeStatus._24h;
    let mass_status = MassState.normal;
    if (custom_info) {
      const customInfo = parseSignatureCustomInfo(custom_info);
      destType = customInfo.destType;
      k162Type = customInfo.k162Type;
      time_status = customInfo.time_status ?? TimeStatus._24h;
      mass_status = customInfo.mass_status ?? MassState.normal;
    }

    signatureForm.reset({
      linked_system: linked_system?.solar_system_id.toString() ?? undefined,
      destType: destType,
      k162Type: k162Type,
      time_status: time_status,
      mass_status: mass_status,
      ...rest,
    });
  }, [signatureForm, signatureData]);

  return (
    <Dialog
      header={`Signature Edit [${signatureData?.eve_id}]`}
      visible={show}
      draggable
      resizable={false}
      style={{ width: '390px' }}
      onShow={handleShow}
      onHide={() => {
        if (!show) {
          return;
        }

        onHide();
      }}
    >
      <SystemsSettingsProvider initialValue={{ systemId }}>
        <FormProvider {...signatureForm}>
          <form onSubmit={handleSave}>
            <div className="flex flex-col gap-2 justify-between">
              <div className="w-full flex flex-col gap-1 p-1 min-h-[150px]">
                <label className="grid grid-cols-[100px_250px_1fr] gap-2 items-center text-[14px]">
                  <span>Group:</span>
                  <SignatureGroupSelect name="group" />
                </label>

                <SignatureGroupContent />

                <label className="grid grid-cols-[100px_250px_1fr] gap-2 items-center text-[14px]">
                  <span>Description:</span>
                  <Controller
                    name="description"
                    control={signatureForm.control}
                    render={({ field }) => (
                      <InputText
                        placeholder="Type description"
                        ref={field.ref}
                        value={field.value}
                        onChange={field.onChange}
                      />
                    )}
                  />
                </label>
              </div>

              <div className="flex gap-2 justify-end px-[0.75rem] pb-[0.5rem]">
                <WdButton type="submit" outlined size="small" label="Save" />
              </div>
            </div>
          </form>
        </FormProvider>
      </SystemsSettingsProvider>
    </Dialog>
  );
};
