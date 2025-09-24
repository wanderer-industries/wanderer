import { useMapRootState } from '@/hooks/Mapper/mapRootProvider';
import {
  ConnectionInfoOutput,
  ConnectionOutput,
  ConnectionType,
  OutCommand,
  Passage,
  SolarSystemConnection,
} from '@/hooks/Mapper/types';
import clsx from 'clsx';
import { Sidebar } from 'primereact/sidebar';
import { VirtualScroller, VirtualScrollerTemplateOptions } from 'primereact/virtualscroller';
import { useCallback, useEffect, useMemo, useState } from 'react';
import classes from './Connections.module.scss';

import { InfoDrawer, SystemView, TimeAgo } from '@/hooks/Mapper/components/ui-kit';
import { kgToTons } from '@/hooks/Mapper/utils/kgToTons.ts';
import { PassageCard } from './PassageCard';

const sortByDate = (a: string, b: string) => new Date(a).getTime() - new Date(b).getTime();

const itemTemplate = (item: Passage, options: VirtualScrollerTemplateOptions) => {
  return (
    <div
      className={clsx(classes.CharacterRow, 'w-full box-border', {
        'surface-hover': options.odd,
        ['border-b border-gray-600 border-opacity-20']: !options.last,
        ['bg-green-500 hover:bg-green-700 transition duration-300 bg-opacity-10 hover:bg-opacity-10']: false,
      })}
      style={{ height: options.props.itemSize + 'px' }}
    >
      <PassageCard {...item} />
    </div>
  );
};

export interface ConnectionPassagesContentProps {
  passages: Passage[];
}

export const ConnectionPassages = ({ passages = [] }: ConnectionPassagesContentProps) => {
  if (passages.length === 0) {
    return <div className="flex justify-center items-center text-stone-400 select-none">Nobody passed here</div>;
  }

  return (
    <VirtualScroller
      items={passages}
      itemSize={43}
      itemTemplate={itemTemplate}
      className={clsx(
        classes.VirtualScroller,
        'w-full h-full overflow-x-hidden overflow-y-auto custom-scrollbar select-none',
      )}
      autoSize={false}
    />
  );
};

export interface OnTheMapProps {
  selectedConnection: SolarSystemConnection | null;
  onHide: () => void;
}

export const Connections = ({ selectedConnection, onHide }: OnTheMapProps) => {
  const {
    data: { connections },
    outCommand,
  } = useMapRootState();

  const cnInfo = useMemo(() => {
    if (!selectedConnection) {
      return null;
    }

    return connections.find(x => x.source === selectedConnection.source && x.target === selectedConnection.target);
  }, [connections, selectedConnection]);

  const isWormhole = useMemo(() => {
    return cnInfo?.type === ConnectionType.wormhole;
  }, [cnInfo]);

  const [passages, setPassages] = useState<Passage[]>([]);
  const [info, setInfo] = useState<ConnectionInfoOutput | null>(null);

  const loadInfo = useCallback(
    async (connection: SolarSystemConnection) => {
      const result = await outCommand<ConnectionInfoOutput>({
        type: OutCommand.getConnectionInfo,
        data: {
          from: connection.source,
          to: connection.target,
        },
      });

      setInfo(result);
    },
    [outCommand],
  );

  const loadPassages = useCallback(
    async (connection: SolarSystemConnection) => {
      const result = await outCommand<ConnectionOutput>({
        type: OutCommand.getPassages,
        data: {
          from: connection.source,
          to: connection.target,
        },
      });

      setPassages(result.passages.sort((a, b) => sortByDate(b.inserted_at, a.inserted_at)));
    },
    [outCommand],
  );

  useEffect(() => {
    if (!selectedConnection) {
      return;
    }
    loadInfo(selectedConnection);
    loadPassages(selectedConnection);
  }, [selectedConnection]);

  const approximateMass = useMemo(() => {
    return passages.reduce((acc, x) => acc + parseInt(x.ship.ship_type_info.mass), 0);
  }, [passages]);

  if (!cnInfo) {
    return null;
  }

  return (
    <Sidebar
      className={clsx(classes.SidebarOnTheMap, 'bg-neutral-900')}
      visible={!!selectedConnection}
      position="right"
      onHide={onHide}
      header="Connection Info"
      icons={<></>}
    >
      <div className={clsx(classes.SidebarContent, '')}>
        {/* Connection Info */}
        <div className="px-2 flex flex-col gap-2">
          {/* Connection Info Row */}
          <InfoDrawer title="Connection" rightSide>
            <div className="flex justify-end gap-2 items-center">
              <SystemView
                systemId={cnInfo.source}
                className={clsx(classes.InfoTextSize, 'select-none text-center')}
                hideRegion
              />
              <span className="pi pi-angle-double-right text-stone-500 text-[15px]"></span>
              <SystemView
                systemId={cnInfo.target}
                className={clsx(classes.InfoTextSize, 'select-none text-center')}
                hideRegion
              />
            </div>
          </InfoDrawer>

          <div className="flex justify-between gap-2">
            {/*Left column*/}
            <div>
              {isWormhole && info?.marl_eol_time && (
                <InfoDrawer title="Mark EOL Time">
                  <TimeAgo timestamp={info.marl_eol_time} />
                </InfoDrawer>
              )}
            </div>

            {/*Right column*/}
            <div>
              {isWormhole && (
                <InfoDrawer title="Approximate mass of passages" rightSide>
                  {kgToTons(approximateMass)}
                </InfoDrawer>
              )}
            </div>
          </div>

          <div className="flex gap-2"></div>
        </div>

        {/* separator */}
        <div className="w-full h-px bg-neutral-800 px-0.5"></div>

        <ConnectionPassages passages={passages} />
      </div>
    </Sidebar>
  );
};
