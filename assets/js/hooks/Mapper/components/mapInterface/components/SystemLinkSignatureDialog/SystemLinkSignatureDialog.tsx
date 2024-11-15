import { useCallback, useRef } from 'react';
import { Dialog } from 'primereact/dialog';

import { OutCommand } from '@/hooks/Mapper/types/mapHandlers.ts';
import { SystemSignature } from '@/hooks/Mapper/types';
import { useMapRootState } from '@/hooks/Mapper/mapRootProvider';
import { CommandLinkSignatureToSystem } from '@/hooks/Mapper/types';
import { SystemSignaturesContent } from '@/hooks/Mapper/components/mapInterface/widgets/SystemSignatures/SystemSignaturesContent';
import {
  Setting,
  COSMIC_SIGNATURE,
} from '@/hooks/Mapper/components/mapInterface/widgets/SystemSignatures/SystemSignatureSettingsDialog';
import { SignatureGroup } from '@/hooks/Mapper/types';

interface SystemLinkSignatureDialogProps {
  data: CommandLinkSignatureToSystem;
  setVisible: (visible: boolean) => void;
}

const signatureSettings: Setting[] = [
  { key: COSMIC_SIGNATURE, name: 'Show Cosmic Signatures', value: true },
  { key: SignatureGroup.Wormhole, name: 'Wormhole', value: true },
];

export const SystemLinkSignatureDialog = ({ data, setVisible }: SystemLinkSignatureDialogProps) => {
  const { outCommand } = useMapRootState();

  const ref = useRef({ outCommand });
  ref.current = { outCommand };

  const handleHide = useCallback(() => {
    setVisible(false);
  }, [setVisible]);

  const handleSelect = useCallback(
    (signature: SystemSignature) => {
      if (!signature) {
        return;
      }

      const { outCommand } = ref.current;

      outCommand({
        type: OutCommand.linkSignatureToSystem,
        data: {
          ...data,
          signature_eve_id: signature.eve_id,
        },
      });
      setVisible(false);
    },
    [data, setVisible],
  );

  return (
    <Dialog
      header="Select signature to link"
      visible
      draggable={false}
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
