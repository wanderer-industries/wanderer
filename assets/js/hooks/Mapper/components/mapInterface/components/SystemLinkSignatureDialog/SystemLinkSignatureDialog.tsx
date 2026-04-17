import { Dialog } from 'primereact/dialog';
import { useCallback, useEffect, useMemo, useRef } from 'react';

import { useSystemInfo } from '@/hooks/Mapper/components/hooks';
import {
    SOLAR_SYSTEM_CLASS_IDS,
    SOLAR_SYSTEM_CLASSES_TO_CLASS_GROUPS,
    WORMHOLES_ADDITIONAL_INFO_BY_SHORT_NAME,
} from '@/hooks/Mapper/components/map/constants.ts';
import { SystemSignaturesContent } from '@/hooks/Mapper/components/mapInterface/widgets/SystemSignatures/SystemSignaturesContent';
import { MULTI_DEST_WHS, ALL_DEST_TYPES_MAP, DEST_TYPES_MAP_MAP } from '@/hooks/Mapper/constants.ts';
import { SETTINGS_KEYS, SignatureSettingsType } from '@/hooks/Mapper/constants/signatures';
import { parseSignatureCustomInfo } from '@/hooks/Mapper/helpers/parseSignatureCustomInfo';
import { useMapRootState } from '@/hooks/Mapper/mapRootProvider';
import { CommandLinkSignatureToSystem, SignatureGroup, SystemSignature } from '@/hooks/Mapper/types';
import { OutCommand } from '@/hooks/Mapper/types/mapHandlers.ts';
import { useSystemSignaturesData } from '../../widgets/SystemSignatures/hooks/useSystemSignaturesData';

const MULTI_DEST_TYPES = MULTI_DEST_WHS.map((type: string) => WORMHOLES_ADDITIONAL_INFO_BY_SHORT_NAME[type].shortName);

interface SystemLinkSignatureDialogProps {
  data: CommandLinkSignatureToSystem;
  setVisible: (visible: boolean) => void;
}

export const LINK_SIGNTATURE_SETTINGS: SignatureSettingsType = {
  [SETTINGS_KEYS.COSMIC_SIGNATURE]: true,
  [SETTINGS_KEYS.WORMHOLE]: true,
  [SETTINGS_KEYS.SHOW_DESCRIPTION_COLUMN]: true,
};

// Extend the SignatureCustomInfo type to include destType
interface ExtendedSignatureCustomInfo {
  destType?: string;
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

      if (MULTI_DEST_TYPES.includes(signature.type)) {
        // Parse the custom info to see if the user has specified what class
        // this wormhole leads to
        const customInfo = parseSignatureCustomInfo(signature.custom_info) as ExtendedSignatureCustomInfo;

        // If the user has specified a destType for this wormhole
        if (customInfo.destType) {
          // Get the destination type information
          const destinationInfo = DEST_TYPES_MAP_MAP[signature.type][customInfo.destType];

          if (destinationInfo) {
            // Check if the destType matches our target system class
            const isDestMatch = destinationInfo.value.includes(targetSystemClassGroup);
            return isDestMatch;
          }
        }
      }

      // Find the wormhole data for this signature type
      const wormholeData = wormholes.find(wh => wh.name === signature.type);
      if (!wormholeData) {
        return true; // If we don't know the destination, don't filter it out
      }

      // Get the destination system classes from the wormhole data
      const destinationClass = wormholeData.dest;

      // If destinationClass is null, then it's K162 and allow, else
      // check if any of the destination classes matches the target system class
      const isMatch = destinationClass == null || destinationClass.includes(targetSystemClassGroup);
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
