import { useState, useEffect, useMemo } from 'react';
import { Dialog } from 'primereact/dialog';
import { DataTable } from 'primereact/datatable';
import { Column } from 'primereact/column';
import { useMapRootState } from '@/hooks/Mapper/mapRootProvider';
import { ProgressSpinner } from 'primereact/progressspinner';
import styles from './CharacterActivity.module.scss';

/**
 * Summary of a character's activity
 */
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

  return (
    <div className="flex items-center p-0.5 w-full overflow-hidden min-w-0">
      <div className="flex items-center w-full">
        <div className="w-5 h-5 rounded-full overflow-hidden flex-shrink-0 mr-2">
          <img src={rowData.portrait_url} alt={displayName} className="w-full h-full object-cover" />
        </div>

        <div className="overflow-hidden text-ellipsis whitespace-nowrap w-[calc(100%-1.75rem)]">
          <span className="font-medium text-text-color-secondary">{displayName}</span>
          <span className="text-text-color-secondary opacity-80 text-xs ml-1">[{rowData.corporation_ticker}]</span>
        </div>
      </div>
    </div>
  );
};

const renderValueTemplate = (rowData: ActivitySummary, field: keyof ActivitySummary) => {
  return (
    <div className="text-center font-medium text-xs leading-tight tabular-nums p-0.5">{rowData[field] as number}</div>
  );
};

/**
 * Component that displays character activity in a dialog.
 */
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

  return (
    <Dialog
      header="Character Activity"
      visible={visible}
      className="bg-surface-card text-text-color w-4/5 max-w-[650px]"
      onHide={onHide}
      dismissableMask
      draggable={false}
      resizable={false}
      closable
      modal={true}
    >
      <div className="w-full h-[400px] flex flex-col overflow-hidden p-0 m-0">
        {loading && (
          <div className="flex flex-col items-center justify-center h-[400px] w-full">
            <ProgressSpinner className={styles.spinnerContainer} strokeWidth="4" />
            <div className="mt-4 text-text-color-secondary text-sm">Loading character activity data...</div>
          </div>
        )}
        {!loading && localActivity.length === 0 && (
          <div className="p-8 text-center text-text-color-secondary italic">No character activity data available</div>
        )}
        {!loading && localActivity.length > 0 && (
          <DataTable
            value={localActivity}
            className="w-full"
            scrollable
            scrollHeight="400px"
            emptyMessage="No character activity data available"
            sortField="passages"
            sortOrder={-1}
            responsiveLayout="scroll"
            size="small"
            rowClassName={getRowClassName}
            rowHover
            resizableColumns
            columnResizeMode="expand"
            tableClassName={styles.dataTable}
          >
            <Column
              field="character_name"
              header="Character"
              body={renderCharacterTemplate}
              sortable
              className={`overflow-hidden text-ellipsis ${styles.characterColumn}`}
              headerClassName="text-xs bg-surface-ground"
            />
            <Column
              field="passages"
              header="Passages"
              body={rowData => renderValueTemplate(rowData, 'passages')}
              sortable
              className={`text-center ${styles.numericColumn}`}
              headerClassName="text-xs bg-surface-ground"
            />
            <Column
              field="connections"
              header="Connections"
              body={rowData => renderValueTemplate(rowData, 'connections')}
              sortable
              className={`text-center ${styles.numericColumn}`}
              headerClassName="text-xs bg-surface-ground"
            />
            <Column
              field="signatures"
              header="Signatures"
              body={rowData => renderValueTemplate(rowData, 'signatures')}
              sortable
              className={`text-center ${styles.numericColumn}`}
              headerClassName="text-xs bg-surface-ground"
            />
          </DataTable>
        )}
      </div>
    </Dialog>
  );
};
