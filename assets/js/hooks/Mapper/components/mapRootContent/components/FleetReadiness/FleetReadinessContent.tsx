import { DataTable } from 'primereact/datatable';
import { Column } from 'primereact/column';
import { useEffect, useState } from 'react';
import { TrackingCharacter, OutCommand } from '@/hooks/Mapper/types';
import { CharacterCard } from '@/hooks/Mapper/components/ui-kit';
import { useMapRootState } from '@/hooks/Mapper/mapRootProvider';
import { getSystemStaticInfo } from '@/hooks/Mapper/mapRootProvider/hooks/useLoadSystemStatic';
import { ProgressSpinner } from 'primereact/progressspinner';

const getRowClassName = () => ['text-xs', 'leading-tight'];

const renderCharacterName = (character: TrackingCharacter) => {
  return (
    <div className="flex items-center gap-2">
      <CharacterCard compact isOwn {...character.character} />
    </div>
  );
};

const renderSystemLocation = (character: TrackingCharacter) => {
  const char = character.character;

  if (!char.location?.solar_system_id) {
    return <span className="text-stone-400">Unknown location</span>;
  }

  const systemStaticInfo = getSystemStaticInfo(char.location.solar_system_id);
  const systemName = systemStaticInfo?.solar_system_name || `System ${char.location.solar_system_id}`;
  const isDocked = char.location.structure_id || char.location.station_id;

  return (
    <div className="flex items-center gap-2">
      <span className="font-medium">{systemName}</span>
      {isDocked && <span className="text-xs text-stone-400">(Docked)</span>}
    </div>
  );
};

const renderShipType = (character: TrackingCharacter) => {
  const char = character.character;

  if (!char.ship?.ship_name) {
    return <span className="text-stone-400">Unknown ship</span>;
  }

  const shipTypeName = char.ship.ship_type_info?.name;

  return (
    <div className="flex items-center space-x-2">
      <span className="font-medium">{shipTypeName || 'Unknown type'}</span>
      <span className="text-xs text-stone-400">({char.ship.ship_name})</span>
    </div>
  );
};

export const FleetReadinessContent = () => {
  const { outCommand } = useMapRootState();
  const [readyCharacters, setReadyCharacters] = useState<TrackingCharacter[]>([]);
  const [loading, setLoading] = useState<boolean>(true);

  useEffect(() => {
    let isMounted = true;

    const loadAllReadyCharacters = async () => {
      if (!isMounted) return;
      setLoading(true);

      try {
        const res = await outCommand({
          type: OutCommand.getAllReadyCharacters,
          data: {},
        });

        // Safe type checking instead of unsafe assertion
        const isValidResponse = (response: unknown): response is { data?: { characters?: TrackingCharacter[] } } => {
          return typeof response === 'object' && 
            response !== null && 
            'data' in response && 
            typeof response.data === 'object' && 
            response.data !== null &&
            (!('characters' in response.data) || Array.isArray((response.data as any).characters));
        };

        if (!isMounted) return;

        if (isValidResponse(res) && res.data && Array.isArray(res.data.characters)) {
          setReadyCharacters(res.data.characters);
        } else {
          console.warn('Invalid response format for getAllReadyCharacters:', res);
          setReadyCharacters([]);
        }
      } catch (err) {
        console.error('Failed to load all ready characters:', err);
        if (isMounted) {
          setReadyCharacters([]);
        }
      }

      if (isMounted) {
        setLoading(false);
      }
    };

    loadAllReadyCharacters();

    return () => {
      isMounted = false;
    };
  }, [outCommand]);

  if (loading) {
    return (
      <div className="flex flex-col items-center justify-center h-full w-full">
        <ProgressSpinner className="w-[50px] h-[50px]" strokeWidth="4" />
        <div className="mt-4 text-text-color-secondary text-sm">Loading Fleet Readiness...</div>
      </div>
    );
  }

  if (readyCharacters.length === 0) {
    return (
      <div className="p-8 text-center text-text-color-secondary italic">
        No characters are currently marked as ready for combat. Characters must be online, tracked, and marked as ready
        to appear here.
        <div className="mt-4 text-xs text-stone-500">
          Tip: Right-click character portraits in the top bar to mark them as ready.
        </div>
      </div>
    );
  }

  return (
    <div className="w-full h-full flex flex-col overflow-hidden">
      {/* Data Table */}
      <div className="flex-1 overflow-auto custom-scrollbar">
        <DataTable
          value={readyCharacters}
          scrollable
          className="w-full"
          tableClassName="w-full border-0"
          emptyMessage="No ready characters found"
          size="small"
          rowClassName={getRowClassName}
          rowHover
        >
          <Column field="character.name" header="Character" body={renderCharacterName} sortable className="!py-[6px]" />
          <Column
            field="character.location"
            header="Location"
            body={renderSystemLocation}
            sortable
            className="!py-[6px]"
          />
          <Column field="character.ship" header="Ship" body={renderShipType} sortable className="!py-[6px]" />
        </DataTable>
      </div>
    </div>
  );
};
