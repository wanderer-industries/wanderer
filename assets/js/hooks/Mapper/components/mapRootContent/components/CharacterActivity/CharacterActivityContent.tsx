import { ProgressSpinner } from 'primereact/progressspinner';
import { DataTable } from 'primereact/datatable';
import {
  getRowClassName,
  renderCharacterTemplate,
  renderValueTemplate,
} from '@/hooks/Mapper/components/mapRootContent/components/CharacterActivity/helpers.tsx';
import { Column } from 'primereact/column';
import { useMapRootState } from '@/hooks/Mapper/mapRootProvider';
import { useMemo } from 'react';

export const CharacterActivityContent = () => {
  const {
    data: { characterActivityData },
  } = useMapRootState();

  const activity = useMemo(() => characterActivityData?.activity || [], [characterActivityData]);
  const loading = useMemo(() => characterActivityData?.loading !== false, [characterActivityData]);

  if (loading) {
    return (
      <div className="flex flex-col items-center justify-center h-full w-full">
        <ProgressSpinner className="w-[50px] h-[50px]" strokeWidth="4" />
        <div className="mt-4 text-text-color-secondary text-sm">Loading character activity data...</div>
      </div>
    );
  }

  if (activity.length === 0) {
    return <div className="p-8 text-center text-text-color-secondary italic">No character activity data available</div>;
  }

  return (
    <div className="w-full h-full overflow-auto custom-scrollbar">
      <DataTable
        value={activity}
        scrollable
        className="w-full"
        tableClassName="w-full border-0"
        emptyMessage="No character activity data available"
        sortField="passages"
        sortOrder={-1}
        size="small"
        rowClassName={getRowClassName}
        rowHover
      >
        <Column
          field="character_name"
          header="Character"
          body={renderCharacterTemplate}
          sortable
          className="!py-[6px]"
        />

        <Column
          field="passages"
          header="Passages"
          headerClassName="[&_.p-column-header-content]:justify-center"
          body={rowData => renderValueTemplate(rowData, 'passages')}
          sortable
        />
        <Column
          field="connections"
          header="Connections"
          headerClassName="[&_.p-column-header-content]:justify-center"
          body={rowData => renderValueTemplate(rowData, 'connections')}
          sortable
        />
        <Column
          field="signatures"
          header="Signatures"
          headerClassName="[&_.p-column-header-content]:justify-center"
          body={rowData => renderValueTemplate(rowData, 'signatures')}
          sortable
        />
      </DataTable>
    </div>
  );
};
