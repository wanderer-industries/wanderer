import { useCallback, useRef, useMemo } from 'react';
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
import { useSystemInfo } from '@/hooks/Mapper/components/hooks';
import { SOLAR_SYSTEM_CLASS_IDS } from '@/hooks/Mapper/components/map/constants.ts';
import { K162_TYPES_MAP } from '@/hooks/Mapper/constants.ts';

interface SystemLinkSignatureDialogProps {
  data: CommandLinkSignatureToSystem;
  setVisible: (visible: boolean) => void;
}

const signatureSettings: Setting[] = [
  { key: COSMIC_SIGNATURE, name: 'Show Cosmic Signatures', value: true },
  { key: SignatureGroup.Wormhole, name: 'Wormhole', value: true },
  { key: SHOW_DESCRIPTION_COLUMN_SETTING, name: 'Show Description Column', value: true, isFilter: false },
];

// Extend the SignatureCustomInfo type to include k162Type
interface ExtendedSignatureCustomInfo {
  k162Type?: string;
  isEOL?: boolean;
  [key: string]: unknown;
}

// Define system class constants to use as a single source of truth
const SYSTEM_CLASSES = {
  C1: 'c1',
  C2: 'c2',
  C3: 'c3',
  C4: 'c4',
  C5: 'c5',
  C6: 'c6',
  HS: 'hs',
  LS: 'ls',
  NS: 'ns',
  THERA: 'thera',
  C13: 'c13',
  ANY: 'any', // Special case for K162
} as const;

// Create a type from our constants for better type safety
type SystemClass = (typeof SYSTEM_CLASSES)[keyof typeof SYSTEM_CLASSES];

// Map system class IDs to their group names
const systemClassToGroup: Record<number, SystemClass> = {
  [SOLAR_SYSTEM_CLASS_IDS.c1]: SYSTEM_CLASSES.C1,
  [SOLAR_SYSTEM_CLASS_IDS.c2]: SYSTEM_CLASSES.C2,
  [SOLAR_SYSTEM_CLASS_IDS.c3]: SYSTEM_CLASSES.C3,
  [SOLAR_SYSTEM_CLASS_IDS.c4]: SYSTEM_CLASSES.C4,
  [SOLAR_SYSTEM_CLASS_IDS.c5]: SYSTEM_CLASSES.C5,
  [SOLAR_SYSTEM_CLASS_IDS.c6]: SYSTEM_CLASSES.C6,
  [SOLAR_SYSTEM_CLASS_IDS.hs]: SYSTEM_CLASSES.HS,
  [SOLAR_SYSTEM_CLASS_IDS.ls]: SYSTEM_CLASSES.LS,
  [SOLAR_SYSTEM_CLASS_IDS.ns]: SYSTEM_CLASSES.NS,
  [SOLAR_SYSTEM_CLASS_IDS.thera]: SYSTEM_CLASSES.THERA,
  [SOLAR_SYSTEM_CLASS_IDS.c13]: SYSTEM_CLASSES.C13,
};

// Map of wormhole types to the system classes they can lead to
const wormholeTypeToDestination: Record<string, SystemClass> = {
  // C1 wormholes
  Z971: SYSTEM_CLASSES.C1,
  L614: SYSTEM_CLASSES.C1,
  C125: SYSTEM_CLASSES.C1,
  O128: SYSTEM_CLASSES.C1,
  Q317: SYSTEM_CLASSES.C1,
  // C2 wormholes
  Z142: SYSTEM_CLASSES.C2,
  D382: SYSTEM_CLASSES.C2,
  N766: SYSTEM_CLASSES.C2,
  R474: SYSTEM_CLASSES.C2,
  X877: SYSTEM_CLASSES.C2,
  // C3 wormholes
  V301: SYSTEM_CLASSES.C3,
  H296: SYSTEM_CLASSES.C3,
  U210: SYSTEM_CLASSES.C3,
  N968: SYSTEM_CLASSES.C3,
  S804: SYSTEM_CLASSES.C3,
  // C4 wormholes
  N110: SYSTEM_CLASSES.C4,
  C247: SYSTEM_CLASSES.C4,
  O477: SYSTEM_CLASSES.C4,
  M267: SYSTEM_CLASSES.C4,
  // C5 wormholes
  H900: SYSTEM_CLASSES.C5,
  N062: SYSTEM_CLASSES.C5,
  V753: SYSTEM_CLASSES.C5,
  Z457: SYSTEM_CLASSES.C5,
  // C6 wormholes
  V911: SYSTEM_CLASSES.C6,
  W237: SYSTEM_CLASSES.C6,
  B520: SYSTEM_CLASSES.C6,
  // HS wormholes
  B274: SYSTEM_CLASSES.HS,
  A239: SYSTEM_CLASSES.HS,
  D845: SYSTEM_CLASSES.HS,
  // LS wormholes
  N944: SYSTEM_CLASSES.LS,
  C391: SYSTEM_CLASSES.LS,
  R943: SYSTEM_CLASSES.LS,
  // NS wormholes
  E545: SYSTEM_CLASSES.NS,
  K346: SYSTEM_CLASSES.NS,
  N432: SYSTEM_CLASSES.NS,
  // Thera wormholes
  V928: SYSTEM_CLASSES.THERA,
  E587: SYSTEM_CLASSES.THERA,
  // C13 wormholes
  S199: SYSTEM_CLASSES.C13,

  K162: SYSTEM_CLASSES.ANY,
};

export const SystemLinkSignatureDialog = ({ data, setVisible }: SystemLinkSignatureDialogProps) => {
  const {
    outCommand,
    data: { wormholes },
  } = useMapRootState();

  const ref = useRef({ outCommand });
  ref.current = { outCommand };

  // Get system info for the target system
  const { staticInfo: targetSystemInfo } = useSystemInfo({ systemId: `${data.solar_system_target}` });

  // Get the system class group for the target system
  const targetSystemClassGroup = useMemo(() => {
    if (!targetSystemInfo) return null;
    const systemClassId = targetSystemInfo.system_class;

    // Get the group name from our mapping
    const group = systemClassToGroup[systemClassId as number] || null;
    return group;
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

      if (signature.type === 'K162') {
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

      const destinationClass = wormholeTypeToDestination[signature.type];
      if (!destinationClass) {
        return true; // If we don't know the destination, don't filter it out
      }

      const isMatch = destinationClass === targetSystemClassGroup;
      return isMatch;
    },
    [targetSystemClassGroup],
  );

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
    [data, setVisible, wormholes],
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
        filterSignature={filterSignature}
      />
    </Dialog>
  );
};
