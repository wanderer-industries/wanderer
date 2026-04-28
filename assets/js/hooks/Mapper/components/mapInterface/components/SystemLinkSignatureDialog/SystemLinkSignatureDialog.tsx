import { Dialog } from 'primereact/dialog';
import { useCallback, useEffect, useMemo, useRef, useState } from 'react';

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
import { handleAutoBookmark, numberToLetters } from '@/hooks/Mapper/helpers/bookmarkFormatHelper.ts';
import { parseSignatureCustomInfo } from '@/hooks/Mapper/helpers/parseSignatureCustomInfo';
import { LabelsManager } from '@/hooks/Mapper/utils/labelsManager.ts';
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

  const [userSettings, setUserSettings] = useState<any>(null);

  useEffect(() => {
    outCommand({ type: OutCommand.getUserSettings, data: null })
      .then((res: any) => setUserSettings(res?.user_settings))
      .catch((e: any) => console.warn('Failed to fetch user settings', e));
  }, [outCommand]);

  const handleSelect = useCallback(
    async (signature: SystemSignature) => {
      if (!signature) {
        return;
      }

      const { outCommand } = ref.current;

      const sourceSystem = systems.find((s: any) => s.system_static_info?.solar_system_id === data.solar_system_source);
      const systemUuid = sourceSystem?.id || data.solar_system_source.toString();

      const { updatedSignature, shouldUpdate } = await handleAutoBookmark(
        signature,
        userSettings,
        systemSignatures,
        systemUuid,
        data.solar_system_source.toString(),
        wormholesData,
        targetSystemClassGroup
      );

      if (shouldUpdate) {
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

      await outCommand({
        type: OutCommand.linkSignatureToSystem,
        data: {
          ...data,
          signature_eve_id: signature.eve_id,
        },
      });

      const systemAutoTag = userSettings?.system_auto_tag;
      const systemCustomLabelName = userSettings?.system_custom_label_name;

      if (systemAutoTag || systemCustomLabelName) {
        const info = parseSignatureCustomInfo(updatedSignature.custom_info);
        const bIndex = info.bookmark_index ?? 0;
        const startAtZero = userSettings?.bookmark_wormholes_start_at_zero;
        const letter = numberToLetters(bIndex, startAtZero);

        const targetSystem = systems.find((s: any) => s.system_static_info?.solar_system_id === data.solar_system_target);

        if (targetSystem) {
          if (systemAutoTag) {
            let tagValue = '';
            switch (systemAutoTag) {
              case 'index':
              case 'chain_index':
                tagValue = bIndex.toString();
                break;
              case 'index_letter':
                tagValue = letter;
                break;
              case 'chain_index_letters':
                tagValue = info.bookmark_index_chained_letters === letter ? letter : bIndex.toString();
                break;
            }

            if (tagValue) {
              await outCommand({
                type: OutCommand.updateSystemTag,
                data: {
                  system_id: targetSystem.id,
                  value: tagValue,
                },
              });
            }
          }

          if (systemCustomLabelName) {
            let labelValue = '';
            switch (systemCustomLabelName) {
              case 'index':
                labelValue = bIndex.toString();
                break;
              case 'index_letter':
                labelValue = letter;
                break;
              case 'chain_index':
                labelValue = info.bookmark_index_chained as string || bIndex.toString();
                break;
              case 'chain_index_letters':
                labelValue = info.bookmark_index_chained_letters as string || letter;
                break;
            }

            if (labelValue) {
              const outLabel = new LabelsManager(targetSystem.labels ?? '');
              outLabel.updateCustomLabel(labelValue);

              await outCommand({
                type: OutCommand.updateSystemLabels,
                data: {
                  system_id: targetSystem.id,
                  value: outLabel.toString(),
                },
              });
            }
          }
        }
      }

      setVisible(false);
    },
    [data, setVisible, userSettings, targetSystemClassGroup, systemSignatures, systems, wormholesData],
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
