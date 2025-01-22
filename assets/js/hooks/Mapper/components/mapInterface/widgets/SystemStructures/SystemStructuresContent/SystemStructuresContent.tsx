import React, { useState, useCallback, useMemo } from 'react';
import { DataTable, DataTableRowClickEvent } from 'primereact/datatable';
import { Column } from 'primereact/column';
import { PrimeIcons } from 'primereact/api';
import clsx from 'clsx';

import { SystemStructuresDialog } from '../SystemStructuresDialog/SystemStructuresDialog';
import { StructureItem } from '../helpers/structureTypes';
import { useHotkey } from '@/hooks/Mapper/hooks';
import classes from './SystemStructuresContent.module.scss';
import { renderOwnerCell, renderTypeCell, renderTimerCell } from '../renders/cellRenders';

interface SystemStructuresContentProps {
  structures: StructureItem[];
  onUpdateStructures: (newList: StructureItem[]) => void;
}

export const SystemStructuresContent: React.FC<SystemStructuresContentProps> = ({ structures, onUpdateStructures }) => {
  const [selectedRow, setSelectedRow] = useState<StructureItem | null>(null);
  const [editingItem, setEditingItem] = useState<StructureItem | null>(null);
  const [showEditDialog, setShowEditDialog] = useState(false);

  const handleRowClick = (e: DataTableRowClickEvent) => {
    const row = e.data as StructureItem;
    setSelectedRow(prev => (prev?.id === row.id ? null : row));
  };

  const handleRowDoubleClick = (e: DataTableRowClickEvent) => {
    setEditingItem(e.data as StructureItem);
    setShowEditDialog(true);
  };

  // Press Delete => remove selected row
  const handleDeleteSelected = useCallback(
    (e: KeyboardEvent) => {
      if (!selectedRow) return;
      e.preventDefault();
      e.stopPropagation();

      const newList = structures.filter(s => s.id !== selectedRow.id);
      onUpdateStructures(newList);
      setSelectedRow(null);
    },
    [selectedRow, structures, onUpdateStructures],
  );

  useHotkey(false, ['Delete', 'Backspace'], handleDeleteSelected);

  const visibleStructures = useMemo(() => {
    return structures;
  }, [structures]);

  return (
    <div className="flex flex-col gap-2 p-2 text-xs text-stone-200 h-full">
      {visibleStructures.length === 0 ? (
        <div className="flex-1 flex justify-center items-center text-stone-400/80 text-sm">No structures</div>
      ) : (
        <div className="flex-1">
          <DataTable
            value={visibleStructures}
            dataKey="id"
            className={clsx(classes.Table, 'w-full select-none h-full')}
            size="small"
            sortMode="single"
            rowHover
            style={{ tableLayout: 'fixed', width: '100%' }}
            onRowClick={handleRowClick}
            onRowDoubleClick={handleRowDoubleClick}
            rowClassName={rowData => {
              const isSelected = selectedRow?.id === rowData.id;
              return clsx(
                classes.TableRowCompact,
                'transition-colors duration-200 cursor-pointer',
                isSelected ? 'bg-amber-500/50 hover:bg-amber-500/70' : 'hover:bg-purple-400/20',
              );
            }}
          >
            <Column
              header="Type"
              body={renderTypeCell}
              style={{
                width: '160px',
                whiteSpace: 'nowrap',
                overflow: 'hidden',
                textOverflow: 'ellipsis',
              }}
            />
            <Column
              field="name"
              header="Name"
              style={{
                width: '120px',
                whiteSpace: 'nowrap',
                overflow: 'hidden',
                textOverflow: 'ellipsis',
              }}
            />
            <Column
              header="Owner"
              body={renderOwnerCell}
              style={{
                width: '120px',
                whiteSpace: 'nowrap',
                overflow: 'hidden',
                textOverflow: 'ellipsis',
              }}
            />
            <Column
              field="status"
              header="Status"
              style={{
                width: '100px',
                whiteSpace: 'nowrap',
                overflow: 'hidden',
                textOverflow: 'ellipsis',
              }}
            />
            <Column
              header="Timer"
              body={renderTimerCell}
              style={{
                width: '110px',
                whiteSpace: 'nowrap',
                overflow: 'hidden',
                textOverflow: 'ellipsis',
              }}
            />
            <Column
              body={(rowData: StructureItem) => (
                <i
                  className={clsx(PrimeIcons.PENCIL, 'text-[14px] cursor-pointer')}
                  title="Edit"
                  onClick={() => {
                    setEditingItem(rowData);
                    setShowEditDialog(true);
                  }}
                />
              )}
              style={{
                width: '40px',
                textAlign: 'center',
                whiteSpace: 'nowrap',
                overflow: 'hidden',
                textOverflow: 'ellipsis',
              }}
            />
          </DataTable>
        </div>
      )}

      {showEditDialog && editingItem && (
        <SystemStructuresDialog
          visible={showEditDialog}
          structure={editingItem}
          onClose={() => setShowEditDialog(false)}
          onSave={(updatedItem: StructureItem) => {
            const newList = structures.map(s => (s.id === updatedItem.id ? updatedItem : s));
            onUpdateStructures(newList);
            setShowEditDialog(false);
          }}
          onDelete={(deleteId: string) => {
            const newList = structures.filter(s => s.id !== deleteId);
            onUpdateStructures(newList);
            setShowEditDialog(false);
          }}
        />
      )}
    </div>
  );
};
