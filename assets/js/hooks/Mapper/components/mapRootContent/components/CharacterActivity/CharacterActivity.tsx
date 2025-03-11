import { useState, useEffect, useMemo } from 'react';
import { Dialog } from 'primereact/dialog';
import { DataTable } from 'primereact/datatable';
import { Column } from 'primereact/column';
import { useMapRootState } from '@/hooks/Mapper/mapRootProvider';
import { ProgressSpinner } from 'primereact/progressspinner';
import classes from './CharacterActivity.module.scss';
import { CharacterCard } from '../../../ui-kit';
import { CharacterTypeRaw } from '@/hooks/Mapper/types';

export interface ActivitySummary {
  character: CharacterTypeRaw;
  passages: number;
  connections: number;
  signatures: number;
}

interface CharacterActivityProps {
  visible: boolean;
  onHide: () => void;
}

const getRowClassName = () => ['text-xs', 'leading-tight', 'p-selectable-row'];

const renderCharacterTemplate = (rowData: ActivitySummary) => {
  return (
    <div className={classes.cellContent}>
      <CharacterCard showShipName={false} showSystem={false} compact isOwn {...rowData.character} />
    </div>
  );
};

const renderValueTemplate = (rowData: ActivitySummary, field: keyof ActivitySummary) => {
  return <div className={`${classes.numericValueCell} tabular-nums`}>{rowData[field] as number}</div>;
};

export const CharacterActivity = ({ visible, onHide }: CharacterActivityProps) => {
  const { data } = useMapRootState();
  const { characterActivityData } = data;
  const [localActivity, setLocalActivity] = useState<ActivitySummary[]>([]);
  const [loading, setLoading] = useState(true);

  const activity = useMemo(() => {
    return characterActivityData?.activity || [];
  }, [characterActivityData]);

  useEffect(() => {
    setLocalActivity(activity);
    setLoading(characterActivityData?.loading !== false);
  }, [activity, characterActivityData]);

  const renderContent = () => {
    if (loading) {
      return (
        <div className="flex flex-col items-center justify-center h-[400px] w-full">
          <ProgressSpinner className={classes.spinnerContainer} strokeWidth="4" />
          <div className="mt-4 text-text-color-secondary text-sm">Loading character activity data...</div>
        </div>
      );
    }

    if (localActivity.length === 0) {
      return (
        <div className="p-8 text-center text-text-color-secondary italic">No character activity data available</div>
      );
    }

    return (
      <DataTable
        value={localActivity}
        scrollable
        scrollHeight="400px"
        resizableColumns
        columnResizeMode="fit"
        className="w-full"
        tableClassName={classes.dataTable}
        emptyMessage="No character activity data available"
        sortField="passages"
        sortOrder={-1}
        responsiveLayout="scroll"
        size="small"
        rowClassName={getRowClassName}
        rowHover
      >
        <Column
          field="character_name"
          header="Character"
          body={renderCharacterTemplate}
          sortable
          headerStyle={{ minWidth: '75px', height: 'auto', overflow: 'visible' }}
          bodyStyle={{ minWidth: '75px' }}
          className={classes.characterColumn}
          headerClassName={`${classes.columnHeader} ${classes.characterHeader}`}
        />

        <Column
          field="passages"
          header="Passages"
          body={rowData => renderValueTemplate(rowData, 'passages')}
          sortable
          headerStyle={{ width: '120px', textAlign: 'center', height: 'auto', overflow: 'visible' }}
          bodyStyle={{ width: '120px', textAlign: 'center' }}
          className={classes.numericColumn}
          headerClassName={`${classes.columnHeader} ${classes.numericColumnHeader}`}
        />
        <Column
          field="connections"
          header="Connections"
          body={rowData => renderValueTemplate(rowData, 'connections')}
          sortable
          headerStyle={{ width: '120px', textAlign: 'center', height: 'auto', overflow: 'visible' }}
          bodyStyle={{ width: '120px', textAlign: 'center' }}
          className={classes.numericColumn}
          headerClassName={`${classes.columnHeader} ${classes.numericColumnHeader}`}
        />
        <Column
          field="signatures"
          header="Signatures"
          body={rowData => renderValueTemplate(rowData, 'signatures')}
          sortable
          headerStyle={{ width: '120px', textAlign: 'center', height: 'auto', overflow: 'visible' }}
          bodyStyle={{ width: '120px', textAlign: 'center' }}
          className={classes.numericColumn}
          headerClassName={`${classes.columnHeader} ${classes.numericColumnHeader}`}
        />
      </DataTable>
    );
  };

  return (
    <Dialog header="Character Activity" visible={visible} className="max-w-[600px]" onHide={onHide} dismissableMask>
      <div className="w-full h-[400px] flex flex-col overflow-hidden p-0 m-0">{renderContent()}</div>
    </Dialog>
  );
};
