import React, { RefObject, useMemo } from 'react';
import { ContextMenu } from 'primereact/contextmenu';
import { PrimeIcons } from 'primereact/api';
import { MenuItem } from 'primereact/menuitem';
import { Edge } from '@reactflow/core/dist/esm/types/edges';
import { ConnectionType, MassState, ShipSizeStatus, SolarSystemConnection, TimeStatus } from '@/hooks/Mapper/types';
import clsx from 'clsx';
import classes from './ContextMenuConnection.module.scss';
import { MASS_STATE_NAMES, MASS_STATE_NAMES_ORDER } from '@/hooks/Mapper/components/map/constants.ts';

export interface ContextMenuConnectionProps {
  contextMenuRef: RefObject<ContextMenu>;
  onDeleteConnection(): void;
  onChangeTimeState(): void;
  onChangeMassState(state: MassState): void;
  onChangeShipSizeStatus(state: ShipSizeStatus): void;
  onToggleMassSave(isLocked: boolean): void;
  onHide(): void;
  edge?: Edge<SolarSystemConnection>;
}

export const ContextMenuConnection: React.FC<ContextMenuConnectionProps> = ({
  contextMenuRef,
  onDeleteConnection,
  onChangeTimeState,
  onChangeMassState,
  onChangeShipSizeStatus,
  onToggleMassSave,
  onHide,
  edge,
}) => {
  const items: MenuItem[] = useMemo(() => {
    if (!edge) {
      return [];
    }

    const isFrigateSize = edge.data?.ship_size_type === ShipSizeStatus.small;
    const isWormhole = edge.data?.type !== ConnectionType.gate;

    return [
      ...(isWormhole
        ? [
            {
              label: `EOL`,
              className: clsx({
                [classes.ConnectionTimeEOL]: edge.data?.time_status === TimeStatus.eol,
              }),
              icon: PrimeIcons.CLOCK,
              command: onChangeTimeState,
            },
          ]
        : []),
      ...(isWormhole
        ? [
            {
              label: `Frigate`,
              className: clsx({
                [classes.ConnectionFrigate]: isFrigateSize,
              }),
              icon: PrimeIcons.CLOUD,
              command: () =>
                onChangeShipSizeStatus(
                  edge.data?.ship_size_type === ShipSizeStatus.small ? ShipSizeStatus.normal : ShipSizeStatus.small,
                ),
            },
          ]
        : []),
      ...(isWormhole
        ? [
            {
              label: `Save mass`,
              className: clsx({
                [classes.ConnectionSave]: edge.data?.locked,
              }),
              icon: PrimeIcons.LOCK,
              command: () => onToggleMassSave(!edge.data?.locked),
            },
          ]
        : []),
      ...(isWormhole && !isFrigateSize
        ? [
            {
              label: `Mass status`,
              icon: PrimeIcons.CHART_PIE,
              items: MASS_STATE_NAMES_ORDER.map(x => ({
                label: MASS_STATE_NAMES[x],
                className: clsx({
                  [classes.SelectedItem]: edge.data?.mass_status === x,
                }),
                command: () => onChangeMassState(x),
              })),
            },
          ]
        : []),
      {
        label: 'Disconnect',
        icon: PrimeIcons.TRASH,
        command: onDeleteConnection,
      },
    ];
  }, [edge, onChangeTimeState, onDeleteConnection, onChangeMassState, onChangeShipSizeStatus]);

  return (
    <>
      <ContextMenu model={items} ref={contextMenuRef} onHide={onHide} breakpoint="767px" />
    </>
  );
};
