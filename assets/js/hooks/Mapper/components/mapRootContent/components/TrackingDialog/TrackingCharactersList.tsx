import { Column } from 'primereact/column';
import { CharacterCard } from '@/hooks/Mapper/components/ui-kit';
import { DataTable } from 'primereact/datatable';
import { useCallback, useEffect, useRef, useState } from 'react';
import { TrackingCharacter } from '@/hooks/Mapper/types';
import { useTracking } from '@/hooks/Mapper/components/mapRootContent/components/TrackingDialog/TrackingProvider.tsx';

export const TrackingCharactersList = () => {
  const [selected, setSelected] = useState<TrackingCharacter[]>([]);
  const { trackingCharacters, updateTracking } = useTracking();
  const refVars = useRef({ trackingCharacters });
  refVars.current = { trackingCharacters };

  useEffect(() => {
    setSelected(trackingCharacters.filter(x => x.tracked));
  }, [trackingCharacters]);

  const handleChangeSelect = useCallback(
    (selected: TrackingCharacter[]) => updateTracking(selected.map(x => x.character.eve_id)),
    [updateTracking],
  );

  return (
    <DataTable
      value={trackingCharacters}
      size="small"
      selectionMode={null}
      selection={selected}
      onSelectionChange={e => handleChangeSelect(e.value)}
      virtualScrollerOptions={{ itemSize: 40 }}
      className="relative w-full select-none min-h-0 h-full"
      resizableColumns={false}
      rowHover
      selectAll
    >
      <Column
        selectionMode="multiple"
        headerClassName="h-[40px] !pl-4"
        className="w-12 max-w-12 !pl-4 [&_div]:mt-[-2px] "
      />
      <Column
        field="eve_id"
        header="Character with tracking access"
        bodyClassName="text-ellipsis overflow-hidden whitespace-nowrap"
        headerClassName="[&_div]:ml-2"
        body={row => {
          return <CharacterCard showShipName={false} showSystem={false} isOwn {...row.character} />;
        }}
      />
    </DataTable>
  );
};
