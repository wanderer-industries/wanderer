import { Column } from 'primereact/column';
import { CharacterCard } from '@/hooks/Mapper/components/ui-kit';
import { DataTable } from 'primereact/datatable';
import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { TrackingCharacter } from '@/hooks/Mapper/types';
import { useTracking } from '@/hooks/Mapper/components/mapRootContent/components/TrackingDialog/TrackingProvider.tsx';

export const TrackingCharactersList = () => {
  const [selected, setSelected] = useState<TrackingCharacter[]>([]);
  const { trackingCharacters, main, following, updateTracking } = useTracking();
  const refVars = useRef({ trackingCharacters });
  refVars.current = { trackingCharacters };

  useEffect(() => {
    setSelected(trackingCharacters.filter(x => x.tracked));
  }, [trackingCharacters]);

  const handleChangeSelect = useCallback(
    (selected: TrackingCharacter[]) => updateTracking(selected.map(x => x.character.eve_id)),
    [updateTracking],
  );

  const items = useMemo(() => {
    let out = trackingCharacters;

    out = out.sort((a, b) => {
      const aId = a.character.eve_id;
      const bId = b.character.eve_id;

      // 1. main always first
      if (aId === main && bId !== main) return -1;
      if (bId === main && aId !== main) return 1;

      // 2. following after main
      if (aId === following && bId !== following) return -1;
      if (bId === following && aId !== following) return 1;

      // 3. sort by name
      return a.character.name.localeCompare(b.character.name);
    });

    return out;
  }, [trackingCharacters, main, following]);

  return (
    <DataTable
      value={items}
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
          return <CharacterCard showCorporationLogo showTicker isOwn {...row.character} />;
        }}
      />
    </DataTable>
  );
};
