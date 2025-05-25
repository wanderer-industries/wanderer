import { Commands, OutCommand } from '@/hooks/Mapper/types';
import { useMapRootState } from '@/hooks/Mapper/mapRootProvider';
import {
  AddHubCommand,
  LoadRoutesCommand,
  RoutesImperativeHandle,
} from '@/hooks/Mapper/components/mapInterface/widgets/RoutesWidget/types.ts';
import { useCallback, useRef } from 'react';
import { RoutesWidget } from '@/hooks/Mapper/components/mapInterface/widgets';
import { useMapEventListener } from '@/hooks/Mapper/events';
import { useLoadRoutes } from '@/hooks/Mapper/components/mapInterface/widgets/RoutesWidget/hooks';

export const WRoutesUser = () => {
  const {
    outCommand,
    storedSettings: { settingsRoutes, settingsRoutesUpdate },
    data: { userHubs, userRoutes },
  } = useMapRootState();

  const ref = useRef<RoutesImperativeHandle>(null);

  const loadRoutesCommand: LoadRoutesCommand = useCallback(
    async (systemId, routesSettings) => {
      outCommand({
        type: OutCommand.getUserRoutes,
        data: {
          system_id: systemId,
          routes_settings: routesSettings,
        },
      });
    },
    [outCommand],
  );

  const addHubCommand: AddHubCommand = useCallback(
    async systemId => {
      if (userHubs.includes(systemId)) {
        return;
      }

      await outCommand({
        type: OutCommand.addUserHub,
        data: { system_id: systemId },
      });
    },
    [userHubs, outCommand],
  );

  const toggleHubCommand: AddHubCommand = useCallback(
    async (systemId: string | undefined) => {
      if (!systemId) {
        return;
      }

      outCommand({
        type: !userHubs.includes(systemId) ? OutCommand.addUserHub : OutCommand.deleteUserHub,
        data: {
          system_id: systemId,
        },
      });
    },
    [userHubs, outCommand],
  );

  // INFO: User routes loading only if open widget with user routes
  const { loading, setLoading } = useLoadRoutes({
    data: settingsRoutes,
    hubs: userHubs,
    loadRoutesCommand,
    routesList: userRoutes,
  });

  useMapEventListener(event => {
    if (event.name === Commands.userRoutes) {
      setLoading(false);
    }
    return true;
  });

  return (
    <RoutesWidget
      ref={ref}
      title="User Routes"
      data={settingsRoutes}
      update={settingsRoutesUpdate}
      hubs={userHubs}
      routesList={userRoutes}
      loading={loading}
      addHubCommand={addHubCommand}
      toggleHubCommand={toggleHubCommand}
      isRestricted
    />
  );
};
