import { useCallback, useEffect, useRef, useState } from 'react';

import { executeLinkSignatureToSystem } from '@/hooks/Mapper/helpers/bookmarkFormatHelper.ts';
import { useMapRootState } from '@/hooks/Mapper/mapRootProvider';
import {
  CommandLinkSignatureToSystem,
  GetUserSettingsResponse,
  SystemSignature,
  UserSettings,
} from '@/hooks/Mapper/types';
import { OutCommand } from '@/hooks/Mapper/types/mapHandlers.ts';

export interface UseLinkSignatureProps {
  data: CommandLinkSignatureToSystem;
  targetSystemClassGroup: string | null;
}

export const useLinkSignature = ({ data, targetSystemClassGroup }: UseLinkSignatureProps) => {
  const {
    outCommand,
    data: { systemSignatures, systems, wormholesData, connections },
  } = useMapRootState();

  const ref = useRef({ outCommand });
  ref.current = { outCommand };

  const [userSettings, setUserSettings] = useState<UserSettings | null>(null);

  useEffect(() => {
    outCommand<GetUserSettingsResponse>({ type: OutCommand.getUserSettings, data: null })
      .then(res => setUserSettings(res?.user_settings ?? null))
      .catch((e: unknown) => console.warn('Failed to fetch user settings', e));
  }, [outCommand]);

  const handleLinkSignature = useCallback(
    async (signature: SystemSignature) => {
      const { outCommand } = ref.current;
      await executeLinkSignatureToSystem({
        signature,
        data,
        targetSystemClassGroup,
        userSettings,
        systemSignatures,
        systems,
        wormholesData,
        connections,
        outCommand,
      });
    },
    [data, userSettings, targetSystemClassGroup, systemSignatures, systems, wormholesData, connections],
  );

  return { handleLinkSignature };
};
