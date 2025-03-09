import { useState, useEffect, useMemo } from 'react';
import { Dialog } from 'primereact/dialog';
import { DataTable } from 'primereact/datatable';
import { Column } from 'primereact/column';
import classes from './CharacterActivity.module.scss';
import { useMapRootState } from '@/hooks/Mapper/mapRootProvider';
import { ProgressSpinner } from 'primereact/progressspinner';

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

const getRowClassName = () => [classes.tableRowCompact, 'p-selectable-row'];

const renderCharacterTemplate = (rowData: ActivitySummary) => {
  return (
    <div className={classes.characterNameCell}>
      <div className={classes.characterInfo}>
        <div className={classes.characterPortrait}>
          <img src={rowData.portrait_url} alt={rowData.character_name} className="w-full h-full object-cover" />
        </div>
        <div className={classes.characterNameContainer}>
          <div className={classes.characterName}>
            {rowData.is_user ? (
              <>
                <span className={classes.nameText}>{rowData.user_name}</span>
                <span className={classes.corporationTicker}>[{rowData.corporation_ticker}]</span>
              </>
            ) : (
              <>
                <span className={classes.nameText}>{rowData.character_name}</span>
                <span className={classes.corporationTicker}>[{rowData.corporation_ticker}]</span>
              </>
            )}
          </div>
        </div>
      </div>
    </div>
  );
};

const renderValueTemplate = (rowData: ActivitySummary, field: keyof ActivitySummary) => {
  return <div className={classes.activityValueCell}>{rowData[field] as number}</div>;
};

/**
 * Component that displays character activity in a dialog.
 */
export const CharacterActivity = ({ visible, onHide }: CharacterActivityProps) => {
  const { data } = useMapRootState();
  const { characterActivityData } = data;
  const [localActivity, setLocalActivity] = useState<ActivitySummary[]>([]);
  const [loading, setLoading] = useState(true);

  // Use the new structure directly
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
      className={classes.characterActivityDialog}
      onHide={onHide}
      dismissableMask
      draggable={false}
      resizable={false}
      closable
      modal={true}
    >
      <div className={classes.characterActivityContainer}>
        {loading && (
          <div className={classes.loadingContainer}>
            <ProgressSpinner style={{ width: '50px', height: '50px' }} strokeWidth="4" />
            <div className={classes.loadingText}>Loading character activity data...</div>
          </div>
        )}
        {!loading && localActivity.length === 0 && (
          <div className={classes.emptyMessage}>No character activity data available</div>
        )}
        {!loading && localActivity.length > 0 && (
          <DataTable
            value={localActivity}
            className={classes.characterActivityDatatable}
            scrollable
            scrollHeight="400px"
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
              className={classes.characterColumn}
              headerClassName={`${classes.headerCharacter} text-xs`}
            />
            <Column
              field="passages"
              header="Passages"
              body={rowData => renderValueTemplate(rowData, 'passages')}
              sortable
              className={classes.numericColumn}
              headerClassName={`${classes.headerStandard} text-xs`}
            />
            <Column
              field="connections"
              header="Connections"
              body={rowData => renderValueTemplate(rowData, 'connections')}
              sortable
              className={classes.numericColumn}
              headerClassName={`${classes.headerStandard} text-xs`}
            />
            <Column
              field="signatures"
              header="Signatures"
              body={rowData => renderValueTemplate(rowData, 'signatures')}
              sortable
              className={classes.numericColumn}
              headerClassName={`${classes.headerStandard} text-xs`}
            />
          </DataTable>
        )}
      </div>
    </Dialog>
  );
};
