import { Map, MAP_ROOT_ID } from '@/hooks/Mapper/components/map/Map.tsx';
import { useCallback, useEffect, useRef, useState } from 'react';
import { OutCommand, OutCommandHandler, SolarSystemConnection } from '@/hooks/Mapper/types';
import { MapRootData, useMapRootState } from '@/hooks/Mapper/mapRootProvider';
import { OnMapAddSystemCallback, OnMapSelectionChange } from '@/hooks/Mapper/components/map/map.types.ts';
import isEqual from 'lodash.isequal';
import { ContextMenuSystem, useContextMenuSystemHandlers } from '@/hooks/Mapper/components/contexts';
import {
  SystemCustomLabelDialog,
  SystemLinkSignatureDialog,
  SystemSettingsDialog,
} from '@/hooks/Mapper/components/mapInterface/components';
import classes from './MapWrapper.module.scss';
import { Connections } from '@/hooks/Mapper/components/mapRootContent/components/Connections';
import { ContextMenuSystemMultiple, useContextMenuSystemMultipleHandlers } from '../contexts/ContextMenuSystemMultiple';
import { getSystemById } from '@/hooks/Mapper/helpers';
import { Commands } from '@/hooks/Mapper/types/mapHandlers.ts';
import { Node, useReactFlow, XYPosition } from 'reactflow';

import { useCommandsSystems } from '@/hooks/Mapper/mapRootProvider/hooks/api';
import { emitMapEvent, useMapEventListener } from '@/hooks/Mapper/events';

import { useDeleteSystems } from '@/hooks/Mapper/components/contexts/hooks';
import { useCommonMapEventProcessor } from '@/hooks/Mapper/components/mapWrapper/hooks/useCommonMapEventProcessor.ts';
import {
  AddSystemDialog,
  SearchOnSubmitCallback,
} from '@/hooks/Mapper/components/mapInterface/components/AddSystemDialog';
import { useHotkey } from '../../hooks/useHotkey';
import { STORED_INTERFACE_DEFAULT_VALUES } from '@/hooks/Mapper/mapRootProvider/constants.ts';

// TODO: INFO - this component needs for abstract work with Map instance
export const MapWrapper = () => {
  const {
    update,
    outCommand,
    data: { selectedConnections, selectedSystems, hubs, userHubs, systems, linkSignatureToSystem, systemSignatures },
    storedSettings: { interfaceSettings },
  } = useMapRootState();

  const {
    isShowMenu,
    isShowMinimap = STORED_INTERFACE_DEFAULT_VALUES.isShowMinimap,
    isShowKSpace,
    isThickConnections,
    isShowBackgroundPattern,
    isShowUnsplashedSignatures,
    isSoftBackground,
    theme,
  } = interfaceSettings;

  const { deleteSystems } = useDeleteSystems();
  const { mapRef, runCommand } = useCommonMapEventProcessor();
  const { getNodes } = useReactFlow();

  const { updateLinkSignatureToSystem } = useCommandsSystems();
  const { open, ...systemContextProps } = useContextMenuSystemHandlers({ systems, hubs, userHubs, outCommand });
  const { handleSystemMultipleContext, ...systemMultipleCtxProps } = useContextMenuSystemMultipleHandlers();

  const [openSettings, setOpenSettings] = useState<string | null>(null);
  const [openCustomLabel, setOpenCustomLabel] = useState<string | null>(null);
  const [openAddSystem, setOpenAddSystem] = useState<XYPosition | null>(null);
  const [selectedConnection, setSelectedConnection] = useState<SolarSystemConnection | null>(null);

  const ref = useRef({
    selectedConnections,
    selectedSystems,
    systemContextProps,
    systems,
    systemSignatures,
    deleteSystems,
  });
  ref.current = { selectedConnections, selectedSystems, systemContextProps, systems, systemSignatures, deleteSystems };

  useMapEventListener(event => {
    runCommand(event);
  });

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
    [handleSystemMultipleContext, open],
  );

  const handleConnectionDbClick = useCallback((e: SolarSystemConnection) => setSelectedConnection(e), []);

  const handleDeleteSelected = useCallback(() => {
    const restDel = getNodes()
      .filter(x => x.selected && !x.data.locked)
      .map(x => x.data.id);
    if (restDel.length > 0) {
      ref.current.deleteSystems(restDel);
    }
  }, [getNodes]);

  const onAddSystem: OnMapAddSystemCallback = useCallback(({ coordinates }) => {
    setOpenAddSystem(coordinates);
  }, []);

  const handleSubmitAddSystem: SearchOnSubmitCallback = useCallback(
    async item => {
      if (ref.current.systems.some(x => parseInt(x.id) === item.value)) {
        emitMapEvent({
          name: Commands.centerSystem,
          data: item.value.toString(),
        });
        return;
      }

      await outCommand({
        type: OutCommand.manualAddSystem,
        data: { coordinates: openAddSystem, solar_system_id: item.value },
      });
    },
    [openAddSystem, outCommand],
  );

  useHotkey(false, ['Delete'], (event: KeyboardEvent) => {
    const targetWindow = (event.target as HTMLHtmlElement)?.closest(`[data-window-id="${MAP_ROOT_ID}"]`);

    if (!targetWindow) {
      return;
    }

    event.preventDefault();
    event.stopPropagation();
    handleDeleteSelected();
  });

  useEffect(() => {
    const { systemSignatures, systems } = ref.current;
    if (!isShowUnsplashedSignatures || Object.keys(systemSignatures).length !== 0 || systems?.length === 0) {
      return;
    }

    outCommand({ type: OutCommand.loadSignatures, data: {} });
  }, [isShowUnsplashedSignatures, systems]);

  return (
    <>
      <Map
        ref={mapRef}
        onCommand={handleCommand}
        onSelectionChange={onSelectionChange}
        onConnectionInfoClick={handleConnectionDbClick}
        onSystemContextMenu={handleSystemContextMenu}
        onSelectionContextMenu={handleSystemMultipleContext}
        minimapClasses={!isShowMenu ? classes.MiniMap : undefined}
        isShowMinimap={isShowMinimap}
        showKSpaceBG={isShowKSpace}
        isThickConnections={isThickConnections}
        isShowBackgroundPattern={isShowBackgroundPattern}
        isSoftBackground={isSoftBackground}
        theme={theme}
        onAddSystem={onAddSystem}
      />

      {openSettings != null && (
        <SystemSettingsDialog systemId={openSettings} visible setVisible={() => setOpenSettings(null)} />
      )}

      {openCustomLabel != null && (
        <SystemCustomLabelDialog systemId={openCustomLabel} visible setVisible={() => setOpenCustomLabel(null)} />
      )}

      {linkSignatureToSystem != null && (
        <SystemLinkSignatureDialog data={linkSignatureToSystem} setVisible={() => updateLinkSignatureToSystem(null)} />
      )}

      <AddSystemDialog
        visible={!!openAddSystem}
        setVisible={() => setOpenAddSystem(null)}
        onSubmit={handleSubmitAddSystem}
      />

      <Connections selectedConnection={selectedConnection} onHide={() => setSelectedConnection(null)} />

      <ContextMenuSystem
        systems={systems}
        hubs={hubs}
        userHubs={userHubs}
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
