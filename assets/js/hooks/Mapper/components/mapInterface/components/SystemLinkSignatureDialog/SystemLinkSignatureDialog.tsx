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
import { getSystemClassGroup } from '@/hooks/Mapper/components/map/helpers/getSystemClassGroup.ts';
import { calculateBookmarkIndex, copyToClipboard, formatBookmarkName, numberToLetters } from '@/hooks/Mapper/helpers/bookmarkFormatHelper.ts';
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

export const LINK_SIGNATURE_SETTINGS: SignatureSettingsType = {
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
    data: { wormholes, systemSignatures, systems, wormholesData },
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
    return getSystemClassGroup(targetSystemInfo.system_class);
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

  const { signatures } = useSystemSignaturesData({
    systemId: `${data.solar_system_source}`,
    settings: LINK_SIGNATURE_SETTINGS,
  });

  const handleSelect = useCallback(
    async (signature: SystemSignature) => {
      if (!signature) {
        return;
      }

      const { outCommand } = ref.current;

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

      let updatedSignature = signature;

      if (signature.group === SignatureGroup.Wormhole && (currentSettings?.bookmark_name_format || currentSettings?.bookmark_auto_temp_name)) {
        const info = parseSignatureCustomInfo(signature.custom_info);
        let bookmarkIndex = info.bookmark_index;

        if (bookmarkIndex == null) {
          const sourceSystem = systems.find((s: any) => s.system_static_info?.solar_system_id === data.solar_system_source);
          const systemUuid = sourceSystem?.id || data.solar_system_source.toString();
          const calculated = calculateBookmarkIndex(
            systemSignatures,
            systemUuid,
            data.solar_system_source.toString(),
            signature.eve_id,
            currentSettings?.bookmark_wormholes_start_at_zero,
          );
          bookmarkIndex = calculated.index;
          info.bookmark_index = calculated.index;
          info.bookmark_index_chained = calculated.chained;
          info.bookmark_index_chained_letters = calculated.chainedLetters;
          updatedSignature = { ...signature, custom_info: JSON.stringify(info) };
        }

        if (currentSettings?.bookmark_auto_temp_name && !updatedSignature.temporary_name) {
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
            updatedSignature = { ...updatedSignature, temporary_name: autoName };
          }
        }

        if (currentSettings?.bookmark_name_format && currentSettings?.bookmark_auto_copy !== false) {
          const formattedStr = formatBookmarkName(
            currentSettings.bookmark_name_format,
            updatedSignature,
            targetSystemClassGroup,
            bookmarkIndex,
            wormholesData,
            currentSettings.bookmark_wormholes_start_at_zero
          );
          
          await copyToClipboard(formattedStr);
        }

        if (updatedSignature !== signature) {
          await outCommand({
            type: OutCommand.updateSignatures,
            data: {
              system_id: `${data.solar_system_source}`,
              updated: [updatedSignature],
              removed: [],
              deleteTimeout: 0,
            },
          });
        }
      }

      await outCommand({
        type: OutCommand.linkSignatureToSystem,
        data: {
          ...data,
          signature_eve_id: signature.eve_id,
        },
      });

      setVisible(false);
    },
    [data, setVisible, signatures, targetSystemClassGroup, systemSignatures, systems, wormholesData],
  );


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
        settings={LINK_SIGNATURE_SETTINGS}
        hideLinkedSignatures
        selectable
        onSelect={handleSelect}
        filterSignature={filterSignature}
      />
    </Dialog>
  );
};
