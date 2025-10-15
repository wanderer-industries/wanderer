import { ContextMenuSystem, useContextMenuSystemHandlers } from '@/hooks/Mapper/components/contexts';
import { Map, MAP_ROOT_ID } from '@/hooks/Mapper/components/map/Map.tsx';
import { OnMapAddSystemCallback, OnMapSelectionChange } from '@/hooks/Mapper/components/map/map.types.ts';
import {
  SystemCustomLabelDialog,
  SystemLinkSignatureDialog,
  SystemSettingsDialog,
} from '@/hooks/Mapper/components/mapInterface/components';
import { Connections } from '@/hooks/Mapper/components/mapRootContent/components/Connections';
import { getSystemById } from '@/hooks/Mapper/helpers';
import { MapRootData, useMapRootState } from '@/hooks/Mapper/mapRootProvider';
import { CommandSelectSystems, OutCommand, OutCommandHandler, SolarSystemConnection } from '@/hooks/Mapper/types';
import { Commands } from '@/hooks/Mapper/types/mapHandlers.ts';
import isEqual from 'lodash.isequal';
import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { Node, useReactFlow, Viewport, XYPosition } from 'reactflow';
import { ContextMenuSystemMultiple, useContextMenuSystemMultipleHandlers } from '../contexts/ContextMenuSystemMultiple';

import { emitMapEvent, useMapEventListener } from '@/hooks/Mapper/events';
import { useCommandsSystems } from '@/hooks/Mapper/mapRootProvider/hooks/api';

import { useDeleteSystems } from '@/hooks/Mapper/components/contexts/hooks';
import {
  AddSystemDialog,
  SearchOnSubmitCallback,
} from '@/hooks/Mapper/components/mapInterface/components/AddSystemDialog';
import { SystemPingDialog } from '@/hooks/Mapper/components/mapInterface/components/SystemPingDialog';
import { useCommonMapEventProcessor } from '@/hooks/Mapper/components/mapWrapper/hooks/useCommonMapEventProcessor.ts';
import { MINIMAP_PLACEMENT_MAP } from '@/hooks/Mapper/constants.ts';
import { MiniMapPlacement } from '@/hooks/Mapper/mapRootProvider/types.ts';
import { PingType } from '@/hooks/Mapper/types/ping.ts';
import type { PanelPosition } from '@reactflow/core';
import { useHotkey } from '../../hooks/useHotkey';
import { MINI_MAP_PLACEMENT_OFFSETS } from './constants.ts';

// TODO: INFO - this component needs for abstract work with Map instance
export const MapWrapper = () => {
  const {
    update,
    outCommand,
    data: {
      pings,
      selectedConnections,
      selectedSystems,
      hubs,
      userHubs,
      systems,
      linkSignatureToSystem,
      systemSignatures,
    },
    storedSettings: { interfaceSettings, settingsLocal, mapSettings, mapSettingsUpdate },
  } = useMapRootState();

  const {
    isShowMenu,
    isShowKSpace,
    isThickConnections,
    isShowBackgroundPattern,
    isShowUnsplashedSignatures,
    isSoftBackground,
    theme,
    minimapPlacement,
  } = interfaceSettings;

  const { deleteSystems } = useDeleteSystems();
  const { mapRef, runCommand } = useCommonMapEventProcessor();
  const { getNodes } = useReactFlow();

  const { updateLinkSignatureToSystem } = useCommandsSystems();
  const { open, ...systemContextProps } = useContextMenuSystemHandlers({ systems, hubs, userHubs, outCommand });
  const { handleSystemMultipleContext, ...systemMultipleCtxProps } = useContextMenuSystemMultipleHandlers();

  const [openSettings, setOpenSettings] = useState<string | null>(null);
  const [openPing, setOpenPing] = useState<{ type: PingType; solar_system_id: string } | null>(null);
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
    mapSettingsUpdate,
  });
  ref.current = {
    selectedConnections,
    selectedSystems,
    systemContextProps,
    systems,
    systemSignatures,
    deleteSystems,
    mapSettingsUpdate,
  };

  useMapEventListener(event => {
    runCommand(event);

    if (event.name === Commands.init) {
      const { selectedSystems } = ref.current;
      if (selectedSystems.length === 0) {
        return;
      }

      runCommand({
        name: Commands.selectSystems,
        data: { systems: selectedSystems, delay: 200 } as CommandSelectSystems,
      });
    }
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

  const handleChangeViewport = useCallback((viewport: Viewport) => {
    ref.current.mapSettingsUpdate({ viewport });
  }, []);

  const handleCommand: OutCommandHandler = useCallback(
    event => {
      switch (event.type) {
        case OutCommand.openSettings:
          // TODO - need fix it
          // @ts-ignore
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
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
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
      .filter(x => !pings.some(p => x.data.id === p.solar_system_id))
      .map(x => x.data.id);

    if (restDel.length > 0) {
      ref.current.deleteSystems(restDel);
    }
  }, [getNodes, pings]);

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

  const handleOpenSettings = useCallback(() => {
    ref.current.systemContextProps.systemId && setOpenSettings(ref.current.systemContextProps.systemId);
  }, []);

  const handleTogglePing = useCallback(
    async (type: PingType, solar_system_id: string, ping_id: string | undefined, hasPing: boolean) => {
      if (hasPing) {
        await outCommand({
          type: OutCommand.cancelPing,
          data: { type, id: ping_id },
        });
        return;
      }

      setOpenPing({ type, solar_system_id });
    },
    [],
  );

  const handleCustomLabelDialog = useCallback(() => {
    const { systemContextProps } = ref.current;
    systemContextProps.systemId && setOpenCustomLabel(systemContextProps.systemId);
  }, []);

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

  const { showMinimap, minimapPosition, minimapClasses } = useMemo(() => {
    const rawPlacement = minimapPlacement == null ? MiniMapPlacement.rightBottom : minimapPlacement;

    if (rawPlacement === MiniMapPlacement.hide) {
      return { minimapPosition: undefined, showMinimap: false, minimapClasses: '' };
    }

    const mmClasses = MINI_MAP_PLACEMENT_OFFSETS[rawPlacement];

    return {
      minimapPosition: MINIMAP_PLACEMENT_MAP[rawPlacement] as PanelPosition,
      showMinimap: true,
      minimapClasses: isShowMenu ? mmClasses.default : mmClasses.withLeftMenu,
    };
  }, [minimapPlacement, isShowMenu]);

  return (
    <>
      <Map
        ref={mapRef}
        onCommand={handleCommand}
        onSelectionChange={onSelectionChange}
        onConnectionInfoClick={handleConnectionDbClick}
        onSystemContextMenu={handleSystemContextMenu}
        onSelectionContextMenu={handleSystemMultipleContext}
        onChangeViewport={handleChangeViewport}
        minimapClasses={minimapClasses}
        isShowMinimap={showMinimap}
        showKSpaceBG={isShowKSpace}
        isThickConnections={isThickConnections}
        isShowBackgroundPattern={isShowBackgroundPattern}
        isSoftBackground={isSoftBackground}
        theme={theme}
        pings={pings}
        onAddSystem={onAddSystem}
        minimapPlacement={minimapPosition}
        localShowShipName={settingsLocal.showShipName}
        defaultViewport={mapSettings.viewport}
      />

      {openSettings != null && (
        <SystemSettingsDialog systemId={openSettings} visible setVisible={() => setOpenSettings(null)} />
      )}
      {openPing != null && (
        <SystemPingDialog
          systemId={openPing.solar_system_id}
          type={openPing.type}
          visible
          setVisible={() => setOpenPing(null)}
        />
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
        onOpenSettings={handleOpenSettings}
        onTogglePing={handleTogglePing}
        onCustomLabelDialog={handleCustomLabelDialog}
      />

      <ContextMenuSystemMultiple {...systemMultipleCtxProps} />
    </>
  );
};
