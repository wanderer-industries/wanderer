import { useState, useEffect } from 'react';
import { Dialog } from 'primereact/dialog';
import { DataTable } from 'primereact/datatable';
import { Column } from 'primereact/column';
import './CharacterActivity.module.scss';

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
  activity: ActivitySummary[];
  onHide: () => void;
}

const getRowClassName = () => 'TableRowCompact';

const renderCharacterTemplate = (rowData: ActivitySummary) => {
  return (
    <div className="character-name-cell flex items-center h-6">
      <div className="character-info flex items-center">
        <div className="character-portrait w-5 h-5 rounded-full overflow-hidden flex-shrink-0 mr-2">
          <img src={rowData.portrait_url} alt={rowData.character_name} className="w-full h-full object-cover" />
        </div>
        <div className="character-name-container overflow-hidden">
          <div className="character-name flex items-center text-xs">
            {rowData.is_user ? (
              <>
                <span className="name-text truncate max-w-[120px]">{rowData.user_name}</span>
                <span className="corporation-ticker ml-1 text-gray-400 truncate">[{rowData.corporation_ticker}]</span>
              </>
            ) : (
              <>
                <span className="name-text truncate max-w-[120px]">{rowData.character_name}</span>
                <span className="corporation-ticker ml-1 text-gray-400 truncate">[{rowData.corporation_ticker}]</span>
              </>
            )}
          </div>
        </div>
      </div>
    </div>
  );
};

const renderValueTemplate = (rowData: ActivitySummary, field: keyof ActivitySummary) => {
  return <div className="activity-value-cell text-xs text-center">{rowData[field] as number}</div>;
};

/**
 * Component that displays character activity in a dialog.
 *
 * This component shows a table of character activity, including:
 * - Character name and portrait
 * - Number of passages traveled
 * - Number of connections created
 * - Number of signatures scanned
 */
export const CharacterActivity = ({ visible, activity, onHide }: CharacterActivityProps) => {
  const [localActivity, setLocalActivity] = useState<ActivitySummary[]>([]);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    try {
      if (Array.isArray(activity)) {
        setLocalActivity(activity);
        setError(null);
      } else {
        console.error('Invalid activity data format:', activity);
        setError('Invalid activity data format');
      }
    } catch (err) {
      console.error('Error processing activity data:', err);
      setError('Error processing activity data');
    }
  }, [activity]);

  const renderHeader = () => (
    <div className="flex justify-between items-center">
      <h2 className="text-xl font-semibold">Character Activity</h2>
    </div>
  );

  const handleHide = () => {
    onHide();
  };

  return (
    <Dialog
      header={renderHeader}
      visible={visible}
      style={{ width: '80vw', maxWidth: '650px' }}
      onHide={handleHide}
      className="character-activity-dialog"
      dismissableMask
      draggable={false}
      resizable={false}
      closeOnEscape
      appendTo={document.body}
      showHeader={true}
      closable={true}
      modal={true}
    >
      <div className="character-activity-container">
        {error && <div className="error-message">{error}</div>}
        {!error && localActivity.length === 0 && (
          <div className="empty-message">No character activity data available</div>
        )}
        {!error && localActivity.length > 0 && (
          <DataTable
            value={localActivity}
            className="character-activity-datatable"
            scrollable
            scrollHeight="100%"
            emptyMessage="No character activity data available"
            sortField="passages"
            sortOrder={-1}
            responsiveLayout="scroll"
            tableStyle={{ tableLayout: 'fixed', width: '100%', margin: 0, padding: 0 }}
            size="small"
            rowClassName={getRowClassName}
            rowHover
          >
            <Column
              field="character_name"
              header="Character"
              body={renderCharacterTemplate}
              sortable
              className="character-column"
              headerClassName="header-character text-xs"
              style={{ width: '40%', height: '24px' }}
              headerStyle={{ height: '24px', padding: '4px 8px' }}
            />
            <Column
              field="passages"
              header="Passages"
              body={rowData => renderValueTemplate(rowData, 'passages')}
              sortable
              className="numeric-column"
              headerClassName="header-standard text-xs"
              style={{ width: '20%', height: '24px' }}
              headerStyle={{ height: '24px', padding: '4px 8px' }}
            />
            <Column
              field="connections"
              header="Connections"
              body={rowData => renderValueTemplate(rowData, 'connections')}
              sortable
              className="numeric-column"
              headerClassName="header-standard text-xs"
              style={{ width: '20%', height: '24px' }}
              headerStyle={{ height: '24px', padding: '4px 8px' }}
            />
            <Column
              field="signatures"
              header="Signatures"
              body={rowData => renderValueTemplate(rowData, 'signatures')}
              sortable
              className="numeric-column"
              headerClassName="header-standard text-xs"
              style={{ width: '20%', height: '24px' }}
              headerStyle={{ height: '24px', padding: '4px 8px' }}
            />
          </DataTable>
        )}
      </div>
    </Dialog>
  );
};
