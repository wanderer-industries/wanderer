import {
  SignatureGroupContent,
  SignatureGroupSelect,
} from '@/hooks/Mapper/components/mapRootContent/components/SignatureSettings/components';
import { getSystemClassGroup } from '@/hooks/Mapper/components/map/helpers/getSystemClassGroup.ts';
import { SystemsSettingsProvider } from '@/hooks/Mapper/components/mapRootContent/components/SignatureSettings/Provider.tsx';
import { WdButton } from '@/hooks/Mapper/components/ui-kit';
import { calculateBookmarkIndex, copyToClipboard, formatBookmarkName, numberToLetters } from '@/hooks/Mapper/helpers/bookmarkFormatHelper.ts';
import { parseSignatureCustomInfo } from '@/hooks/Mapper/helpers/parseSignatureCustomInfo';
import { useMapRootState } from '@/hooks/Mapper/mapRootProvider';
import { MassState, OutCommand, SignatureGroup, SystemSignature, TimeStatus } from '@/hooks/Mapper/types';
import { Dialog } from 'primereact/dialog';
import { InputText } from 'primereact/inputtext';
import { useCallback, useEffect } from 'react';
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
    data: { systemSignatures, systems, wormholesData },
  } = useMapRootState();

  const handleShow = async () => {};

  const signatureForm = useForm<Partial<SystemSignaturePrepared>>({});

  const handleSave = useCallback(
    // TODO: need fix
    async (e: any) => {
      e?.preventDefault();
      if (!signatureData) {
        return;
      }

      const { group, ...values } = signatureForm.getValues();
      let out = { ...signatureData };

      switch (group) {
        case SignatureGroup.Wormhole:
          const existingInfo = parseSignatureCustomInfo(signatureData.custom_info);
          out = {
            ...out,
            custom_info: JSON.stringify({
              ...existingInfo,
              destType: values.destType,
              k162Type: values.k162Type,
              time_status: values.time_status,
              mass_status: values.mass_status,
            }),
          };

          if (values.type != null) {
            out = { ...out, type: values.type };
          }

          if (values.temporary_name != null) {
            out = { ...out, temporary_name: values.temporary_name };
          }

          if (signatureData.group !== SignatureGroup.Wormhole) {
            out = { ...out, name: '' };
          }

          break;
        case SignatureGroup.CosmicSignature:
          out = { ...out, type: '', name: '' };
          break;
        default:
          if (values.name != null) {
            out = { ...out, name: values.name ?? '' };
          }
      }

      if (values.description != null) {
        out = { ...out, description: values.description };
      }

      // Note: when type of signature changed from WH to other type - we should drop name
      if (
        group !== SignatureGroup.Wormhole && // new
        signatureData.group === SignatureGroup.Wormhole && // prev
        signatureData.linked_system
      ) {
        await outCommand({
          type: OutCommand.unlinkSignature,
          data: { signature_eve_id: signatureData.eve_id, solar_system_source: systemId },
        });

        out = { ...out, type: '' };
      }

      if (group === SignatureGroup.Wormhole && signatureData.linked_system != null && values.linked_system === null) {
        await outCommand({
          type: OutCommand.unlinkSignature,
          data: { signature_eve_id: signatureData.eve_id, solar_system_source: systemId },
        });
      }

      // Note: despite groups have optional type - this will always set
      out = { ...out, group: group! };

      if (group === SignatureGroup.Wormhole) {
        let currentSettings = null;
        try {
          const res = (await outCommand({
            type: OutCommand.getUserSettings,
            data: null,
          })) as any;
          currentSettings = res?.user_settings;
        } catch (e) {
          console.warn('Failed to fetch user settings', e);
        }

        if (currentSettings?.bookmark_name_format || currentSettings?.bookmark_auto_temp_name) {
          const info = parseSignatureCustomInfo(out.custom_info);

          let bookmarkIndex = info.bookmark_index;
          if (bookmarkIndex == null) {
            const currentSystem = systems.find((s: any) => s.id === systemId);
            const solarSystemIdStr = currentSystem?.system_static_info?.solar_system_id?.toString() || systemId;
            const calculated = calculateBookmarkIndex(
              systemSignatures,
              systemId,
              solarSystemIdStr,
              out.eve_id,
              currentSettings?.bookmark_wormholes_start_at_zero,
            );
            bookmarkIndex = calculated.index;
            info.bookmark_index = calculated.index;
            info.bookmark_index_chained = calculated.chained;
            info.bookmark_index_chained_letters = calculated.chainedLetters;
            out.custom_info = JSON.stringify(info);
          }

          if (currentSettings?.bookmark_auto_temp_name && !out.temporary_name) {
            let autoName = '';
            switch (currentSettings.bookmark_auto_temp_name) {
              case 'index':
                autoName = bookmarkIndex.toString();
                break;
              case 'index_letter':
                autoName = numberToLetters(bookmarkIndex, currentSettings.bookmark_wormholes_start_at_zero);
                break;
              case 'chain_index':
                autoName = info.bookmark_index_chained || bookmarkIndex.toString();
                break;
              case 'chain_index_letters':
                autoName = info.bookmark_index_chained_letters || info.bookmark_index_chained || bookmarkIndex.toString();
                break;
            }
            if (autoName) {
              out.temporary_name = autoName;
            }
          }

          if (currentSettings?.bookmark_name_format && currentSettings?.bookmark_auto_copy !== false) {
            const targetSystem = values.linked_system ? systems.find((s: any) => s.id === values.linked_system) : null;
            const targetSystemClassGroup = targetSystem?.system_static_info ? getSystemClassGroup(targetSystem.system_static_info.system_class) : null;

            const formattedStr = formatBookmarkName(
              currentSettings.bookmark_name_format,
              out,
              targetSystemClassGroup,
              bookmarkIndex,
              wormholesData,
              currentSettings.bookmark_wormholes_start_at_zero
            );
            
            await copyToClipboard(formattedStr);
          }
        }
      }

      await outCommand({
        type: OutCommand.updateSignatures,
        data: {
          system_id: systemId,
          added: [],
          updated: [out],
          removed: [],
          deleteTimeout: 0,
        },
      });

      // Link after updateSignatures so the K162's linked_system_id is still nil
      // during signature update, preventing maybe_update_connection_* from
      // resetting connection properties set by the forward signature.
      if (group === SignatureGroup.Wormhole && values.linked_system) {
        await outCommand({
          type: OutCommand.linkSignatureToSystem,
          data: {
            signature_eve_id: signatureData.eve_id,
            solar_system_source: systemId,
            solar_system_target: values.linked_system,
          },
        });
      }

      signatureForm.reset();
      onHide();
    },
    [signatureData, signatureForm, outCommand, systemId, onHide, systemSignatures, systems, wormholesData],
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
                      <InputText placeholder="Type description" value={field.value} onChange={field.onChange} />
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
