import React, { useCallback, useEffect, useState } from 'react';
import { Dialog } from 'primereact/dialog';
import { AutoComplete } from 'primereact/autocomplete';
import { Calendar } from 'primereact/calendar';
import clsx from 'clsx';

import { formatToISO, statusesRequiringTimer, StructureItem, StructureStatus } from '../helpers';
import { useMapRootState } from '@/hooks/Mapper/mapRootProvider';
import { OutCommand } from '@/hooks/Mapper/types';
import { WdButton } from '@/hooks/Mapper/components/ui-kit';

interface StructuresEditDialogProps {
  visible: boolean;
  structure?: StructureItem;
  onClose: () => void;
  onSave: (updatedItem: StructureItem) => void;
  onDelete: (id: string) => void;
}

export const SystemStructuresDialog: React.FC<StructuresEditDialogProps> = ({
  visible,
  structure,
  onClose,
  onSave,
  onDelete,
}) => {
  const [editData, setEditData] = useState<StructureItem | null>(null);
  const [ownerInput, setOwnerInput] = useState('');
  const [ownerSuggestions, setOwnerSuggestions] = useState<{ label: string; value: string }[]>([]);

  const { outCommand } = useMapRootState();

  const [prevQuery, setPrevQuery] = useState('');
  const [prevResults, setPrevResults] = useState<{ label: string; value: string }[]>([]);

  useEffect(() => {
    if (structure) {
      setEditData(structure);
      setOwnerInput(structure.ownerName ?? '');
    } else {
      setEditData(null);
      setOwnerInput('');
    }
  }, [structure]);

  // Searching corporation owners via auto-complete
  const searchOwners = useCallback(
    async (e: { query: string }) => {
      const newQuery = e.query.trim();
      if (!newQuery) {
        setOwnerSuggestions([]);
        return;
      }

      // If user typed more text but we have partial match in prevResults
      if (newQuery.startsWith(prevQuery) && prevResults.length > 0) {
        const filtered = prevResults.filter(item => item.label.toLowerCase().includes(newQuery.toLowerCase()));
        setOwnerSuggestions(filtered);
        return;
      }

      try {
        // TODO fix it
        const { results = [] } = await outCommand({
          type: OutCommand.getCorporationNames,
          data: { search: newQuery },
        });
        setOwnerSuggestions(results);
        setPrevQuery(newQuery);
        setPrevResults(results);
      } catch (err) {
        console.error('Failed to fetch owners:', err);
        setOwnerSuggestions([]);
      }
    },
    [prevQuery, prevResults, outCommand],
  );

  const handleChange = (field: keyof StructureItem, val: string | Date) => {
    // If we want to forbid changing structureTypeId or structureType from the dialog, do so here:
    if (field === 'structureTypeId' || field === 'structureType') return;

    setEditData(prev => {
      if (!prev) return null;

      // If this is the endTime (Date from Calendar), we store as ISO or string:
      if (field === 'endTime' && val instanceof Date) {
        return { ...prev, endTime: val.toISOString() };
      }

      return { ...prev, [field]: val };
    });
  };

  // when user picks a corp from auto-complete
  const handleSelectOwner = (selected: { label: string; value: string }) => {
    setOwnerInput(selected.label);
    setEditData(prev => (prev ? { ...prev, ownerName: selected.label, ownerId: selected.value } : null));
  };

  const handleStatusChange = (val: string) => {
    setEditData(prev => {
      if (!prev) return null;
      const newStatus = val as StructureStatus;
      // If new status doesn't require a timer, we clear out endTime
      const newEndTime = statusesRequiringTimer.includes(newStatus) ? prev.endTime : '';
      return { ...prev, status: newStatus, endTime: newEndTime };
    });
  };

  const handleSaveClick = async () => {
    if (!editData) return;

    // If status doesn't require a timer, clear endTime
    if (!statusesRequiringTimer.includes(editData.status)) {
      editData.endTime = '';
    } else if (editData.endTime) {
      // convert to full ISO if not already
      editData.endTime = formatToISO(editData.endTime);
    }

    // fetch corporation ticker if we have an ownerId
    if (editData.ownerId) {
      try {
        // TODO fix it
        const { ticker } = await outCommand({
          type: OutCommand.getCorporationTicker,
          data: { corp_id: editData.ownerId },
        });
        editData.ownerTicker = ticker ?? '';
      } catch (err) {
        console.error('Failed to fetch ticker:', err);
        editData.ownerTicker = '';
      }
    }

    onSave(editData);
  };

  const handleDeleteClick = () => {
    if (!editData) return;
    onDelete(editData.id);
    onClose();
  };

  if (!editData) return null;

  return (
    <Dialog
      visible={visible}
      onHide={onClose}
      header={`Edit Structure - ${editData.name ?? ''}`}
      className={clsx('myStructuresDialog', 'text-stone-200 w-full max-w-md')}
    >
      <div className="flex flex-col gap-2 text-[14px]">
        <label className="grid grid-cols-[100px_250px_1fr] gap-2 items-center">
          <span>Type:</span>
          <input readOnly className="p-inputtext p-component cursor-not-allowed" value={editData.structureType ?? ''} />
        </label>
        <label className="grid grid-cols-[100px_250px_1fr] gap-2 items-center">
          <span>Name:</span>
          <input
            className="p-inputtext p-component"
            value={editData.name ?? ''}
            onChange={e => handleChange('name', e.target.value)}
          />
        </label>
        <label className="grid grid-cols-[100px_250px_1fr] gap-2 items-center">
          <span>Owner:</span>
          <AutoComplete
            id="owner"
            value={ownerInput}
            suggestions={ownerSuggestions}
            completeMethod={searchOwners}
            minLength={3}
            delay={400}
            field="label"
            placeholder="Corporation name..."
            onChange={e => setOwnerInput(e.value)}
            onSelect={e => handleSelectOwner(e.value)}
          />
        </label>
        <label className="grid grid-cols-[100px_250px_1fr] gap-2 items-center">
          <span>Status:</span>
          <select
            className="p-inputtext p-component"
            value={editData.status}
            onChange={e => handleStatusChange(e.target.value)}
          >
            <option value="Powered">Powered</option>
            <option value="Anchoring">Anchoring</option>
            <option value="Unanchoring">Unanchoring</option>
            <option value="Low Power">Low Power</option>
            <option value="Abandoned">Abandoned</option>
            <option value="Reinforced">Reinforced</option>
          </select>
        </label>

        {statusesRequiringTimer.includes(editData.status) && (
          <label className="grid grid-cols-[100px_250px_1fr] gap-2 items-center">
            <span>
              Timer <br /> (Eve Time):
            </span>
            <Calendar
              value={editData.endTime ? new Date(editData.endTime) : undefined}
              onChange={e => handleChange('endTime', e.value ?? '')}
              showTime
              hourFormat="24"
              dateFormat="yy-mm-dd"
              showIcon
            />
          </label>
        )}

        <label className="grid grid-cols-[100px_1fr] gap-2 items-start mt-2">
          <span className="mt-1">Notes:</span>
          <textarea
            className="p-inputtext p-component resize-none h-24"
            value={editData.notes ?? ''}
            onChange={e => handleChange('notes', e.target.value)}
          />
        </label>
      </div>

      <div className="flex justify-end items-center gap-2 mt-4">
        <WdButton label="Delete" severity="danger" className="p-button-sm" onClick={handleDeleteClick} />
        <WdButton label="Save" className="p-button-sm" onClick={handleSaveClick} />
      </div>
    </Dialog>
  );
};
