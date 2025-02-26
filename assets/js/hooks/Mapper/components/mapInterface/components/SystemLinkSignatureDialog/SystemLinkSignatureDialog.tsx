import { useCallback, useEffect, useRef } from 'react';
import { Dialog } from 'primereact/dialog';

import { OutCommand } from '@/hooks/Mapper/types/mapHandlers.ts';
import { SystemSignature, TimeStatus } from '@/hooks/Mapper/types';
import { useMapRootState } from '@/hooks/Mapper/mapRootProvider';
import { CommandLinkSignatureToSystem } from '@/hooks/Mapper/types';
import { SystemSignaturesContent } from '@/hooks/Mapper/components/mapInterface/widgets/SystemSignatures/SystemSignaturesContent';
import { SHOW_DESCRIPTION_COLUMN_SETTING } from '@/hooks/Mapper/components/mapInterface/widgets/SystemSignatures/SystemSignatures';
import {
  Setting,
  COSMIC_SIGNATURE,
} from '@/hooks/Mapper/components/mapInterface/widgets/SystemSignatures/SystemSignatureSettingsDialog';
import { SignatureGroup } from '@/hooks/Mapper/types';
import { parseSignatureCustomInfo } from '@/hooks/Mapper/helpers/parseSignatureCustomInfo';
import { getWhSize } from '@/hooks/Mapper/helpers/getWhSize';

interface SystemLinkSignatureDialogProps {
  data: CommandLinkSignatureToSystem;
  setVisible: (visible: boolean) => void;
}

const signatureSettings: Setting[] = [
  { key: COSMIC_SIGNATURE, name: 'Show Cosmic Signatures', value: true },
  { key: SignatureGroup.Wormhole, name: 'Wormhole', value: true },
  { key: SHOW_DESCRIPTION_COLUMN_SETTING, name: 'Show Description Column', value: true, isFilter: false },
];

export const SystemLinkSignatureDialog = ({ data, setVisible }: SystemLinkSignatureDialogProps) => {
  const {
    outCommand,
    data: { wormholes },
  } = useMapRootState();

  const ref = useRef({ outCommand });
  ref.current = { outCommand };

  const handleHide = useCallback(() => {
    setVisible(false);
  }, [setVisible]);

  const handleSelect = useCallback(
    async (signature: SystemSignature) => {
      if (!signature) {
        return;
      }

      const { outCommand } = ref.current;

      await outCommand({
        type: OutCommand.linkSignatureToSystem,
        data: {
          ...data,
          signature_eve_id: signature.eve_id,
        },
      });

      if (parseSignatureCustomInfo(signature.custom_info).isEOL === true) {
        await outCommand({
          type: OutCommand.updateConnectionTimeStatus,
          data: {
            source: data.solar_system_source,
            target: data.solar_system_target,
            value: TimeStatus.eol,
          },
        });
      }

      const whShipSize = getWhSize(wormholes, signature.type);
      if (whShipSize) {
        await outCommand({
          type: OutCommand.updateConnectionShipSizeType,
          data: {
            source: data.solar_system_source,
            target: data.solar_system_target,
            value: whShipSize,
          },
        });
      }

      setVisible(false);
    },
    [data, setVisible],
  );

  return (
    <Dialog
      header="Select signature to link"
      visible
      draggable={true}
      style={{ width: '500px' }}
      onHide={handleHide}
      contentClassName="!p-0"
    >
      <SystemSignaturesContent
        systemId={`${data.solar_system_source}`}
        hideLinkedSignatures
        settings={signatureSettings}
        onSelect={handleSelect}
        selectable={true}
      />
    </Dialog>
  );
};
