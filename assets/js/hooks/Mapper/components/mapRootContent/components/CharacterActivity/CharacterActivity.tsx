import { useState, useEffect, useMemo } from 'react';
import { Dialog } from 'primereact/dialog';
import { DataTable } from 'primereact/datatable';
import { Column } from 'primereact/column';
import { useMapRootState } from '@/hooks/Mapper/mapRootProvider';
import { ProgressSpinner } from 'primereact/progressspinner';
import classes from './CharacterActivity.module.scss';

export interface ActivitySummary {
  character_id: string;
  character_name: string;
  corporation_ticker: string;
  alliance_ticker?: string;
  portrait_url: string;
  passages: number;
  connections: number;
  signatures: number;
  user_id?: string;
  user_name?: string;
  is_user?: boolean;
}

interface CharacterActivityProps {
  visible: boolean;
  onHide: () => void;
}

const getRowClassName = () => ['text-xs leading-tight', 'p-selectable-row'];

const renderCharacterTemplate = (rowData: ActivitySummary) => {
  const displayName = rowData.is_user ? rowData.user_name : rowData.character_name;
  const ticker = rowData.corporation_ticker;
  const allianceTicker = rowData.alliance_ticker ? `[${rowData.alliance_ticker}]` : '';

  return (
    <div className={classes.cellContent}>
      <div className="w-6 h-6 rounded-full overflow-hidden flex-shrink-0 mr-3">
        <img src={rowData.portrait_url} alt={displayName} className="w-full h-full object-cover" />
      </div>
      <div className={classes.characterInfo}>
        <div className={classes.characterName}>
          <span className="font-medium text-text-color">{displayName}</span>
        </div>
        <div className={classes.characterTicker}>
          <span className="text-text-color-secondary text-xs">
            [{ticker}] {allianceTicker}
          </span>
        </div>
      </div>
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
          headerStyle={{ minWidth: '75px', padding: '0.5rem', height: 'auto', overflow: 'visible' }}
          bodyStyle={{ minWidth: '75px' }}
          className={classes.characterColumn}
          headerClassName={`${classes.columnHeader} ${classes.characterHeader}`}
        />

        <Column
          field="passages"
          header="Passages"
          body={rowData => renderValueTemplate(rowData, 'passages')}
          sortable
          headerStyle={{ width: '120px', textAlign: 'center', padding: '0.5rem', height: 'auto', overflow: 'visible' }}
          bodyStyle={{ width: '120px', textAlign: 'center' }}
          className={classes.numericColumn}
          headerClassName={`${classes.columnHeader} ${classes.numericColumnHeader}`}
        />
        <Column
          field="connections"
          header="Connections"
          body={rowData => renderValueTemplate(rowData, 'connections')}
          sortable
          headerStyle={{ width: '120px', textAlign: 'center', padding: '0.5rem', height: 'auto', overflow: 'visible' }}
          bodyStyle={{ width: '120px', textAlign: 'center' }}
          className={classes.numericColumn}
          headerClassName={`${classes.columnHeader} ${classes.numericColumnHeader}`}
        />
        <Column
          field="signatures"
          header="Signatures"
          body={rowData => renderValueTemplate(rowData, 'signatures')}
          sortable
          headerStyle={{ width: '120px', textAlign: 'center', padding: '0.5rem', height: 'auto', overflow: 'visible' }}
          bodyStyle={{ width: '120px', textAlign: 'center' }}
          className={classes.numericColumn}
          headerClassName={`${classes.columnHeader} ${classes.numericColumnHeader}`}
        />
      </DataTable>
    );
  };

  return (
    <Dialog
      header="Character Activity"
      visible={visible}
      className="bg-surface-card text-text-color w-11/12 max-w-[600px]"
      onHide={onHide}
      dismissableMask
    >
      <div className="w-full h-[400px] flex flex-col overflow-hidden p-0 m-0">{renderContent()}</div>
    </Dialog>
  );
};
