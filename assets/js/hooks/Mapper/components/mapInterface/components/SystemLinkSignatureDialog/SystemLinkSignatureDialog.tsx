import { Dialog } from 'primereact/dialog';
import { useCallback, useEffect, useMemo, useRef } from 'react';

import { useSystemInfo } from '@/hooks/Mapper/components/hooks';
import {
  SOLAR_SYSTEM_CLASS_IDS,
  SOLAR_SYSTEM_CLASSES_TO_CLASS_GROUPS,
  WORMHOLES_ADDITIONAL_INFO_BY_SHORT_NAME,
} from '@/hooks/Mapper/components/map/constants.ts';
import { SystemSignaturesContent } from '@/hooks/Mapper/components/mapInterface/widgets/SystemSignatures/SystemSignaturesContent';
import { K162_TYPES_MAP } from '@/hooks/Mapper/constants.ts';
import { SETTINGS_KEYS, SignatureSettingsType } from '@/hooks/Mapper/constants/signatures';
import { parseSignatureCustomInfo } from '@/hooks/Mapper/helpers/parseSignatureCustomInfo';
import { useMapRootState } from '@/hooks/Mapper/mapRootProvider';
import { CommandLinkSignatureToSystem, SignatureGroup, SystemSignature } from '@/hooks/Mapper/types';
import { OutCommand } from '@/hooks/Mapper/types/mapHandlers.ts';
import { useSystemSignaturesData } from '../../widgets/SystemSignatures/hooks/useSystemSignaturesData';

const K162_SIGNATURE_TYPE = WORMHOLES_ADDITIONAL_INFO_BY_SHORT_NAME['K162'].shortName;

interface SystemLinkSignatureDialogProps {
  data: CommandLinkSignatureToSystem;
  setVisible: (visible: boolean) => void;
}

export const LINK_SIGNTATURE_SETTINGS: SignatureSettingsType = {
  [SETTINGS_KEYS.COSMIC_SIGNATURE]: true,
  [SETTINGS_KEYS.WORMHOLE]: true,
  [SETTINGS_KEYS.SHOW_DESCRIPTION_COLUMN]: true,
};

// Extend the SignatureCustomInfo type to include k162Type
interface ExtendedSignatureCustomInfo {
  k162Type?: string;
  isEOL?: boolean;
  [key: string]: unknown;
}

export const SystemLinkSignatureDialog = ({ data, setVisible }: SystemLinkSignatureDialogProps) => {
  const {
    outCommand,
    data: { wormholes },
  } = useMapRootState();

  const ref = useRef({ outCommand });
  ref.current = { outCommand };

  // Get system info for the target system
  const { staticInfo: targetSystemInfo, dynamicInfo: targetSystemDynamicInfo } = useSystemInfo({
    systemId: `${data.solar_system_target}`,
  });

  // Get the system class group for the target system
  const targetSystemClassGroup = useMemo(() => {
    if (!targetSystemInfo) return null;
    const systemClassId = targetSystemInfo.system_class;

    const systemClassKey = Object.keys(SOLAR_SYSTEM_CLASS_IDS).find(
      key => SOLAR_SYSTEM_CLASS_IDS[key as keyof typeof SOLAR_SYSTEM_CLASS_IDS] === systemClassId,
    );

    if (!systemClassKey) return null;

    return (
      SOLAR_SYSTEM_CLASSES_TO_CLASS_GROUPS[systemClassKey as keyof typeof SOLAR_SYSTEM_CLASSES_TO_CLASS_GROUPS] || null
    );
  }, [targetSystemInfo]);

  const handleHide = useCallback(() => {
    setVisible(false);
  }, [setVisible]);

  const filterSignature = useCallback(
    (signature: SystemSignature) => {
      if (signature.group !== SignatureGroup.Wormhole || !targetSystemClassGroup) {
        return true;
      }

      if (!signature.type) {
        return true;
      }

      if (signature.type === K162_SIGNATURE_TYPE) {
        // Parse the custom info to see if the user has specified what class this K162 leads to
        const customInfo = parseSignatureCustomInfo(signature.custom_info) as ExtendedSignatureCustomInfo;

        // If the user has specified a k162Type for this K162
        if (customInfo.k162Type) {
          // Get the K162 type information
          const k162TypeInfo = K162_TYPES_MAP[customInfo.k162Type];

          if (k162TypeInfo) {
            // Check if the k162Type matches our target system class
            return customInfo.k162Type === targetSystemClassGroup;
          }
        }

        // If no k162Type is specified or we couldn't find type info, allow it
        return true;
      }

      // Find the wormhole data for this signature type
      const wormholeData = wormholes.find(wh => wh.name === signature.type);
      if (!wormholeData) {
        return true; // If we don't know the destination, don't filter it out
      }

      // Get the destination system class from the wormhole data
      const destinationClass = wormholeData.dest;

      // Check if the destination class matches the target system class
      const isMatch = destinationClass === targetSystemClassGroup;
      return isMatch;
    },
    [targetSystemClassGroup, wormholes],
  );

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

  const { signatures } = useSystemSignaturesData({
    systemId: `${data.solar_system_source}`,
    settings: LINK_SIGNTATURE_SETTINGS,
  });

  useEffect(() => {
    if (!targetSystemDynamicInfo) {
      handleHide();
    }
  }, [targetSystemDynamicInfo]);

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
        signatures={signatures}
        hasUnsupportedLanguage={false}
        settings={LINK_SIGNTATURE_SETTINGS}
        hideLinkedSignatures
        selectable
        onSelect={handleSelect}
        filterSignature={filterSignature}
      />
    </Dialog>
  );
};
