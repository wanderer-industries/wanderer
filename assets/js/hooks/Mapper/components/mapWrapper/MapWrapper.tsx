import { Map, MAP_ROOT_ID } from '@/hooks/Mapper/components/map/Map.tsx';
import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
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
import { PingType } from '@/hooks/Mapper/types/ping.ts';
import { SystemPingDialog } from '@/hooks/Mapper/components/mapInterface/components/SystemPingDialog';
import { MiniMapPlacement } from '@/hooks/Mapper/mapRootProvider/types.ts';
import { MINIMAP_PLACEMENT_MAP } from '@/hooks/Mapper/constants.ts';
import type { PanelPosition } from '@reactflow/core';
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
    storedSettings: { interfaceSettings, settingsLocal },
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

  const handleTogglePing = useCallback(async (type: PingType, solar_system_id: string, hasPing: boolean) => {
    if (hasPing) {
      // Find the ping for this solar system to get its ID
      const ping = pings.find(p => p.solar_system_id === solar_system_id);
      if (!ping) {
        console.error('Cannot find ping for solar system:', solar_system_id);
        return;
      }
      
      await outCommand({
        type: OutCommand.cancelPing,
        data: { type, id: ping.id },
      });
      return;
    }

    setOpenPing({ type, solar_system_id });
  }, [pings, outCommand]);

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
