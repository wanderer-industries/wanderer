import { useMapRootState } from '@/hooks/Mapper/mapRootProvider';
import { useEffect, useState } from 'react';

export const useDetectSettingsChanged = () => {
  const {
    storedSettings: {
      interfaceSettings,
      settingsRoutes,
      settingsLocal,
      settingsSignatures,
      settingsOnTheMap,
      settingsKills,
    },
  } = useMapRootState();
  const [counter, setCounter] = useState(0);

  useEffect(
    () => setCounter(x => x + 1),
    [interfaceSettings, settingsRoutes, settingsLocal, settingsSignatures, settingsOnTheMap, settingsKills],
  );

  return counter;
};
