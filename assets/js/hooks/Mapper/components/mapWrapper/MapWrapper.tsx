import { Map } from '@/hooks/Mapper/components/map/Map.tsx';
import { ForwardedRef, useCallback, useRef, useState } from 'react';
import { MapHandlers, OutCommand, OutCommandHandler, SolarSystemConnection } from '@/hooks/Mapper/types';
import { MapRootData, useMapRootState } from '@/hooks/Mapper/mapRootProvider';
import { OnMapSelectionChange } from '@/hooks/Mapper/components/map/map.types.ts';
import isEqual from 'lodash.isequal';
import { ContextMenuSystem, useContextMenuSystemHandlers } from '@/hooks/Mapper/components/contexts';
import { SystemCustomLabelDialog, SystemSettingsDialog } from '@/hooks/Mapper/components/mapInterface/components';
import classes from './MapWrapper.module.scss';
import { Connections } from '@/hooks/Mapper/components/mapRootContent/components/Connections';
import { ContextMenuSystemMultiple, useContextMenuSystemMultipleHandlers } from '../contexts/ContextMenuSystemMultiple';
import { getSystemById } from '@/hooks/Mapper/helpers';
import { Node } from 'reactflow';

import { STORED_INTERFACE_DEFAULT_VALUES } from '@/hooks/Mapper/mapRootProvider/MapRootProvider';

interface MapWrapperProps {
  refn: ForwardedRef<MapHandlers>;
}

// TODO: INFO - this component needs for abstract work with Map instance
export const MapWrapper = ({ refn }: MapWrapperProps) => {
  const {
    update,
    outCommand,
    data: { selectedConnections, selectedSystems, hubs, systems },
    interfaceSettings: { isShowMenu, isShowMinimap = STORED_INTERFACE_DEFAULT_VALUES.isShowMinimap, isShowKSpace },
  } = useMapRootState();

  const { open, ...systemContextProps } = useContextMenuSystemHandlers({ systems, hubs, outCommand });
  const { handleSystemMultipleContext, ...systemMultipleCtxProps } = useContextMenuSystemMultipleHandlers();

  const ref = useRef({ selectedConnections, selectedSystems, systemContextProps, systems });
  ref.current = { selectedConnections, selectedSystems, systemContextProps, systems };

  const onSelectionChange: OnMapSelectionChange = useCallback(
    ({ systems, connections }) => {
      const { selectedConnections, selectedSystems } = ref.current;

      const newData: Partial<Pick<MapRootData, 'selectedSystems' | 'selectedConnections'>> = {};

      if (!isEqual(systems, selectedSystems)) {
        newData.selectedSystems = systems;
      }

      if (!isEqual(connections, selectedConnections)) {
        newData.selectedConnections = connections;
      }

      update(newData);
    },
    [update],
  );

  const [openSettings, setOpenSettings] = useState<string | null>(null);
  const [openCustomLabel, setOpenCustomLabel] = useState<string | null>(null);
  const handleCommand: OutCommandHandler = useCallback(
    event => {
      switch (event.type) {
        case OutCommand.openSettings:
          setOpenSettings(event.data.system_id);
          break;
        default:
          return outCommand(event);
      }
      // @ts-ignore
      return new Promise(resolve => resolve(null));
    },
    [outCommand],
  );

  const handleSystemContextMenu = useCallback(
    (ev: any, systemId: string) => {
      const { selectedSystems, systems } = ref.current;
      if (selectedSystems.length > 1) {
        const systemsInfo: Node[] = selectedSystems.map(x => ({ data: getSystemById(systems, x), id: x }) as Node);

        handleSystemMultipleContext(ev, systemsInfo);
        return;
      }

      open(ev, systemId);
    },
    [open],
  );

  const [selectedConnection, setSelectedConnection] = useState<SolarSystemConnection | null>(null);

  const handleConnectionDbClick = useCallback((e: SolarSystemConnection) => setSelectedConnection(e), []);

  return (
    <>
      <Map
        ref={refn}
        onCommand={handleCommand}
        onSelectionChange={onSelectionChange}
        onConnectionInfoClick={handleConnectionDbClick}
        onSystemContextMenu={handleSystemContextMenu}
        onSelectionContextMenu={handleSystemMultipleContext}
        minimapClasses={!isShowMenu ? classes.MiniMap : undefined}
        isShowMinimap={isShowMinimap}
        showKSpaceBG={isShowKSpace}
      />

      {openSettings != null && (
        <SystemSettingsDialog
          systemId={openSettings}
          visible={openSettings != null}
          setVisible={() => setOpenSettings(null)}
        />
      )}

      {openCustomLabel != null && (
        <SystemCustomLabelDialog
          systemId={openCustomLabel}
          visible={openCustomLabel != null}
          setVisible={() => setOpenCustomLabel(null)}
        />
      )}

      <Connections selectedConnection={selectedConnection} onHide={() => setSelectedConnection(null)} />

      <ContextMenuSystem
        systems={systems}
        hubs={hubs}
        {...systemContextProps}
        onOpenSettings={() => {
          systemContextProps.systemId && setOpenSettings(systemContextProps.systemId);
        }}
        onCustomLabelDialog={() => {
          const { systemContextProps } = ref.current;
          systemContextProps.systemId && setOpenCustomLabel(systemContextProps.systemId);
        }}
      />

      <ContextMenuSystemMultiple {...systemMultipleCtxProps} />
    </>
  );
};
