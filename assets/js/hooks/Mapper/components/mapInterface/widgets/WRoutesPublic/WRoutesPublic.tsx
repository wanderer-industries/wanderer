import { Commands, OutCommand } from '@/hooks/Mapper/types';
import { useMapRootState } from '@/hooks/Mapper/mapRootProvider';
import {
  AddHubCommand,
  RoutesImperativeHandle,
} from '@/hooks/Mapper/components/mapInterface/widgets/RoutesWidget/types.ts';
import { useCallback, useRef } from 'react';
import { RoutesWidget } from '@/hooks/Mapper/components/mapInterface/widgets';
import { useMapEventListener } from '@/hooks/Mapper/events';

export const WRoutesPublic = () => {
  const {
    outCommand,
    storedSettings: { settingsRoutes, settingsRoutesUpdate },
    data: { hubs, routes, loadingPublicRoutes },
  } = useMapRootState();

  const ref = useRef<RoutesImperativeHandle>(null);

  const addHubCommand: AddHubCommand = useCallback(
    async systemId => {
      if (hubs.includes(systemId)) {
        return;
      }

      await outCommand({
        type: OutCommand.addHub,
        data: { system_id: systemId },
      });
    },
    [hubs, outCommand],
  );

  const toggleHubCommand: AddHubCommand = useCallback(
    async (systemId: string | undefined) => {
      if (!systemId) {
        return;
      }

      outCommand({
        type: !hubs.includes(systemId) ? OutCommand.addHub : OutCommand.deleteHub,
        data: {
          system_id: systemId,
        },
      });
    },
    [hubs, outCommand],
  );

  useMapEventListener(event => {
    if (event.name === Commands.routes) {
      ref.current?.stopLoading();
    }
  });

  return (
    <RoutesWidget
      ref={ref}
      title="Routes"
      data={settingsRoutes}
      loading={loadingPublicRoutes}
      update={settingsRoutesUpdate}
      hubs={hubs}
      routesList={routes}
      addHubCommand={addHubCommand}
      toggleHubCommand={toggleHubCommand}
    />
  );
};
