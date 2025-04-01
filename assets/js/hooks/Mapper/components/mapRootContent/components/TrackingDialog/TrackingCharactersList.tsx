import { Column } from 'primereact/column';
import { CharacterCard } from '@/hooks/Mapper/components/ui-kit';
import { DataTable } from 'primereact/datatable';
import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { useMapRootState } from '@/hooks/Mapper/mapRootProvider';
import { OutCommand, TrackingCharacter } from '@/hooks/Mapper/types';

export const TrackingCharactersList = () => {
  const [selected, setSelected] = useState<TrackingCharacter[]>([]);

  const {
    outCommand,
    data: { trackingCharactersData },
  } = useMapRootState();

  const characters = useMemo(() => trackingCharactersData ?? [], [trackingCharactersData]);
  const refVars = useRef({ characters });
  refVars.current = { characters };

  useEffect(() => {
    setSelected(characters.filter(x => x.tracked));
  }, [characters]);

  const handleTrackToggle = useCallback(
    async (characterId: string) => {
      try {
        await outCommand({
          type: OutCommand.toggleTrack,
          data: { character_id: characterId },
        });
      } catch (error) {
        console.error('Error toggling track:', error);
      }
    },
    [outCommand],
  );

  const handleChangeSelect = useCallback(
    (selected: TrackingCharacter[]) => {
      const needToCheck = refVars.current.characters.filter(char => {
        return !char.tracked && selected.some(x => x.character.eve_id === char.character.eve_id);
      });
      const needToUncheck = refVars.current.characters.filter(char => {
        return char.tracked && !selected.some(x => x.character.eve_id === char.character.eve_id);
      });

      needToUncheck.map(x => handleTrackToggle(x.character.eve_id));
      needToCheck.map(x => handleTrackToggle(x.character.eve_id));
    },
    [handleTrackToggle],
  );

  return (
    <DataTable
      value={characters}
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
