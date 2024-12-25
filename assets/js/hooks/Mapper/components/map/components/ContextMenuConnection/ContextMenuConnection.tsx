import React, { RefObject, useMemo } from 'react';
import { ContextMenu } from 'primereact/contextmenu';
import { PrimeIcons } from 'primereact/api';
import { MenuItem } from 'primereact/menuitem';
import { Edge } from '@reactflow/core/dist/esm/types/edges';
import { ConnectionType, MassState, ShipSizeStatus, SolarSystemConnection, TimeStatus } from '@/hooks/Mapper/types';
import clsx from 'clsx';
import classes from './ContextMenuConnection.module.scss';
import {
  MASS_STATE_NAMES,
  MASS_STATE_NAMES_ORDER,
  SHIP_SIZES_NAMES,
  SHIP_SIZES_NAMES_ORDER,
  SHIP_SIZES_NAMES_SHORT,
  SHIP_SIZES_SIZE,
} from '@/hooks/Mapper/components/map/constants.ts';

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
            {
              label: `Frigate`,
              className: clsx({
                [classes.ConnectionFrigate]: isFrigateSize,
              }),
              icon: PrimeIcons.CLOUD,
              command: () =>
                onChangeShipSizeStatus(
                  edge.data?.ship_size_type === ShipSizeStatus.small ? ShipSizeStatus.large : ShipSizeStatus.small,
                ),
            },
            {
              label: `Save mass`,
              className: clsx({
                [classes.ConnectionSave]: edge.data?.locked,
              }),
              icon: PrimeIcons.LOCK,
              command: () => onToggleMassSave(!edge.data?.locked),
            },
            ...(!isFrigateSize
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
              label: `Ship Size`,
              icon: PrimeIcons.CLOUD,
              items: SHIP_SIZES_NAMES_ORDER.map(x => ({
                label: (
                  <div className="grid grid-cols-[20px_120px_1fr_40px] gap-2 items-center">
                    <div className="text-[12px] font-bold text-stone-400">{SHIP_SIZES_NAMES_SHORT[x]}</div>
                    <div>{SHIP_SIZES_NAMES[x]}</div>
                    <div></div>
                    <div className="flex justify-end whitespace-nowrap text-[12px] font-bold text-stone-500">
                      {SHIP_SIZES_SIZE[x]} t.
                    </div>
                  </div>
                ) as unknown as string, // TODO my lovely kostyl
                className: clsx({
                  [classes.SelectedItem]: edge.data?.ship_size_type === x,
                }),
                command: () => onChangeShipSizeStatus(x),
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
  }, [edge, onChangeTimeState, onDeleteConnection, onChangeShipSizeStatus, onToggleMassSave, onChangeMassState]);

  return (
    <>
      <ContextMenu model={items} ref={contextMenuRef} onHide={onHide} breakpoint="767px" />
    </>
  );
};
