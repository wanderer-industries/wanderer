import { Dialog } from 'primereact/dialog';
import { useCallback, useEffect } from 'react';
import { OutCommand, SignatureGroup, SystemSignature, TimeStatus } from '@/hooks/Mapper/types';
import { Controller, FormProvider, useForm } from 'react-hook-form';
import {
  SignatureGroupContent,
  SignatureGroupSelect,
} from '@/hooks/Mapper/components/mapRootContent/components/SignatureSettings/components';
import { InputText } from 'primereact/inputtext';
import { SystemsSettingsProvider } from '@/hooks/Mapper/components/mapRootContent/components/SignatureSettings/Provider.tsx';
import { Button } from 'primereact/button';
import { useMapRootState } from '@/hooks/Mapper/mapRootProvider';
import { getWhSize } from '@/hooks/Mapper/helpers/getWhSize';

type SystemSignaturePrepared = Omit<SystemSignature, 'linked_system'> & { linked_system: string };

export interface MapSettingsProps {
  systemId: string;
  show: boolean;
  onHide: () => void;
  signatureData: SystemSignature | undefined;
}

export const SignatureSettings = ({ systemId, show, onHide, signatureData }: MapSettingsProps) => {
  const {
    outCommand,
    data: { wormholes },
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
          if (values.linked_system) {
            await outCommand({
              type: OutCommand.linkSignatureToSystem,
              data: {
                signature_eve_id: signatureData.eve_id,
                solar_system_source: systemId,
                solar_system_target: values.linked_system,
              },
            });

            // TODO: need fix
            if (values.isEOL) {
              await outCommand({
                type: OutCommand.updateConnectionTimeStatus,
                data: {
                  source: systemId,
                  target: values.linked_system,
                  value: TimeStatus.eol,
                },
              });
            }

            if (values.type) {
              const whShipSize = getWhSize(wormholes, values.type);
              if (whShipSize !== undefined && whShipSize !== null) {
                await outCommand({
                  type: OutCommand.updateConnectionShipSizeType,
                  data: {
                    source: systemId,
                    target: values.linked_system,
                    value: whShipSize,
                  },
                });
              }
            }
          }

          out = {
            ...out,
            custom_info: JSON.stringify({
              // TODO: need fix
              k162Type: values.k162Type,
              // TODO: need fix
              isEOL: values.isEOL,
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

      await outCommand({
        type: OutCommand.updateSignatures,
        data: {
          system_id: systemId,
          added: [],
          updated: [out],
          removed: [],
        },
      });

      signatureForm.reset();
      onHide();
    },
    [signatureData, signatureForm, outCommand, systemId, onHide, wormholes],
  );

  useEffect(() => {
    if (!signatureData) {
      signatureForm.reset();
      return;
    }

    const { linked_system, custom_info, ...rest } = signatureData;

    let k162Type = null;
    let isEOL = false;
    if (custom_info) {
      const customInfo = JSON.parse(custom_info);
      k162Type = customInfo.k162Type;
      isEOL = customInfo.isEOL;
    }

    signatureForm.reset({
      linked_system: linked_system?.solar_system_id.toString() ?? undefined,
      // TODO: need fix
      k162Type: k162Type,
      isEOL: isEOL,
      ...rest,
    });
  }, [signatureForm, signatureData]);

  return (
    <Dialog
      header={`Signature Edit [${signatureData?.eve_id}]`}
      visible={show}
      draggable={true}
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

              <div className="flex gap-2 justify-end">
                <Button onClick={handleSave} outlined size="small" label="Save"></Button>
              </div>
            </div>
          </form>
        </FormProvider>
      </SystemsSettingsProvider>
    </Dialog>
  );
};
