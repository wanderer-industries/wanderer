import { MapUserAddIcon, MapUserDeleteIcon } from '@/hooks/Mapper/icons';
import { useMapRootState } from '@/hooks/Mapper/mapRootProvider';
import { useCallback, useRef } from 'react';
import { WidgetsIds } from '@/hooks/Mapper/components/mapInterface/constants.tsx';

interface UseUserRouteProps {
  systemId: string | undefined;
  userHubs: string[];
  onUserHubToggle(): void;
}

export const useUserRoute = ({ userHubs, systemId, onUserHubToggle }: UseUserRouteProps) => {
  const {
    data: { isSubscriptionActive },
    windowsSettings,
  } = useMapRootState();

  const ref = useRef({ userHubs, systemId, onUserHubToggle, isSubscriptionActive, windowsSettings });
  ref.current = { userHubs, systemId, onUserHubToggle, isSubscriptionActive, windowsSettings };

  return useCallback(() => {
    const { userHubs, systemId, onUserHubToggle, isSubscriptionActive, windowsSettings } = ref.current;

    const isVisibleUserRoutes = windowsSettings.visible.some(x => x === WidgetsIds.userRoutes);

    if (!isSubscriptionActive || !isVisibleUserRoutes || !systemId) {
      return [];
    }

    return [
      {
        label: !userHubs.includes(systemId) ? 'Add User Route' : 'Remove User Route',
        icon: !userHubs.includes(systemId) ? (
          <MapUserAddIcon className="mr-1 relative left-[-2px]" />
        ) : (
          <MapUserDeleteIcon className="mr-1 relative left-[-2px]" />
        ),
        command: onUserHubToggle,
      },
    ];
  }, [windowsSettings]);
};
