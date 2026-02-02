import clsx from 'clsx';
import { AutoComplete } from 'primereact/autocomplete';
import { Dialog } from 'primereact/dialog';
import React, { useCallback, useState } from 'react';

import { WdButton } from '@/hooks/Mapper/components/ui-kit';
import { useMapRootState } from '@/hooks/Mapper/mapRootProvider';
import { useToast } from '@/hooks/Mapper/ToastProvider';
import { OutCommand } from '@/hooks/Mapper/types';
import { StructureItem } from '../helpers';

interface StructuresOwnersEditDialogProps {
  visible: boolean;
  structures: StructureItem[];
  onClose: () => void;
  onSave: (updatedStuctures: StructureItem[]) => void;
}

export const SystemStructuresOwnersDialog: React.FC<StructuresOwnersEditDialogProps> = ({
  visible,
  structures,
  onClose,
  onSave,
}) => {
  const [ownerInput, setOwnerInput] = useState('');
  const [ownerSuggestions, setOwnerSuggestions] = useState<{ label: string; value: string }[]>([]);

  const { outCommand } = useMapRootState();
  const { show } = useToast();

  const [prevQuery, setPrevQuery] = useState('');
  const [prevResults, setPrevResults] = useState<{ label: string; value: string }[]>([]);
  const [editData, setEditData] = useState<StructureItem[]>(structures);

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
        show({
          severity: 'error',
          summary: 'Failed to fetch owners',
          detail: `${err}`,
          life: 10000,
        });
      }
    },
    [prevQuery, prevResults, outCommand],
  );

  // when user picks a corp from auto-complete
  const handleSelectOwner = (selected: { label: string; value: string }) => {
    setOwnerInput(selected.label);

    setEditData(
      structures.map(item => {
        return { ...item, ownerName: selected.label, ownerId: selected.value };
      }),
    );
  };

  const handleSaveClick = async () => {
    if (!editData) return;

    // Get all unique owner IDs that need ticker lookup
    const allOwnerIds = editData.filter(x => x.ownerId != null).map(x => x.ownerId as string);

    const uniqueOwnerIds = [...new Set(allOwnerIds)];

    // Fetch all tickers in parallel
    const tickerResults = await Promise.all(
      uniqueOwnerIds.map(async ownerId => {
        try {
          const { ticker } = await outCommand({
            type: OutCommand.getCorporationTicker,
            data: { corp_id: ownerId },
          });
          return { ownerId, ticker: ticker ?? '' };
        } catch (err) {
          console.error('Failed to fetch ticker for ownerId:', ownerId, err);
          return { ownerId, ticker: '' };
        }
      }),
    );

    // Create a map of ownerId -> ticker for quick lookup
    const tickerMap = new Map(tickerResults.map(r => [r.ownerId, r.ticker]));

    // Create new array with updated values (no mutation)
    const updatedStructures = editData.map(structure => {
      if (!structure.ownerId) {
        return structure;
      }

      return {
        ...structure,
        ownerTicker: tickerMap.get(structure.ownerId) ?? '',
      };
    });

    onSave(updatedStructures);
    onClose();
  };

  return (
    <Dialog
      visible={visible}
      onHide={onClose}
      header={'Update All Structure Owners'}
      className={clsx('myStructuresOwnersDialog', 'text-stone-200 w-full max-w-md')}
    >
      <div className="flex flex-col gap-2 text-[14px]">
        <div className="flex gap-2">
          Updating the corporation name below will update all structures currently saved within the system.
        </div>

        <hr />

        <div className="flex flex-col gap-2">
          <label className="grid grid-cols-[100px_1fr] gap-2 items-start mt-2">
            <span className="mt-1">Structures to update:</span>
            <ul>
              {structures &&
                structures.map((item, i) => (
                  <li key={i}>
                    {item.structureType || 'Unknown Type'} - {item.name}
                  </li>
                ))}
            </ul>
          </label>
        </div>

        <hr />

        <div>
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
        </div>
      </div>

      <div className="flex justify-end items-center gap-2 mt-4">
        <WdButton label="Save" className="p-button-sm" onClick={handleSaveClick} />
      </div>
    </Dialog>
  );
};
