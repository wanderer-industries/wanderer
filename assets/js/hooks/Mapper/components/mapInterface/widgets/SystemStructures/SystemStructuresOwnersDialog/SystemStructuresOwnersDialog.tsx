import React, { useCallback, useState } from 'react';
import { Dialog } from 'primereact/dialog';
import { AutoComplete } from 'primereact/autocomplete';
import clsx from 'clsx';

import { StructureItem } from '../helpers';
import { useMapRootState } from '@/hooks/Mapper/mapRootProvider';
import { OutCommand } from '@/hooks/Mapper/types';
import { WdButton } from '@/hooks/Mapper/components/ui-kit';

interface StructuresOwnersEditDialogProps {
  visible: boolean;
  structures?: StructureItem[];
  onClose: () => void;
  onSave: (updatedItem: StructureItem) => void;
}

export const SystemStructuresOwnersDialog: React.FC<StructuresOwnersEditDialogProps> = ({
  visible,
  structures,
  onClose,
  onSave,
}) => {
  console.log("RENDERING OWNERS DIALOG")
  const [ownerInput, setOwnerInput] = useState('');
  const [ownerSuggestions, setOwnerSuggestions] = useState<{ label: string; value: string }[]>([]);

  const { outCommand } = useMapRootState();

  const [prevQuery, setPrevQuery] = useState('');
  const [prevResults, setPrevResults] = useState<{ label: string; value: string }[]>([]);

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


  // // when user picks a corp from auto-complete
  // const handleSelectOwner = (selected: { label: string; value: string }) => {
  //   setOwnerInput(selected.label);
  //   setEditData(prev => (prev ? { ...prev, ownerName: selected.label, ownerId: selected.value } : null));
  // };
  //
  // const handleSaveClick = async () => {
  //   if (!editData) return;
  //
  //   // If status doesn't require a timer, clear endTime
  //   if (!statusesRequiringTimer.includes(editData.status)) {
  //     editData.endTime = '';
  //   } else if (editData.endTime) {
  //     // convert to full ISO if not already
  //     editData.endTime = formatToISO(editData.endTime);
  //   }
  //
  //   // fetch corporation ticker if we have an ownerId
  //   if (editData.ownerId) {
  //     try {
  //       // TODO fix it
  //       const { ticker } = await outCommand({
  //         type: OutCommand.getCorporationTicker,
  //         data: { corp_id: editData.ownerId },
  //       });
  //       editData.ownerTicker = ticker ?? '';
  //     } catch (err) {
  //       console.error('Failed to fetch ticker:', err);
  //       editData.ownerTicker = '';
  //     }
  //   }
  //
  //   onSave(editData);
  // };

  // if (!editData) return null;

  console.log("Just before return statement")

  return (
    <Dialog
      visible={visible}
      onHide={onClose}
      header={'Update All Structure Owners'}
      className={clsx('myStructuresOwnersDialog', 'text-stone-200 w-full max-w-md')}
    >
      <div className="flex flex-col gap-2 text-[14px]">
        <div className="flex gap-2">
          Updating the corporation name below will update all structures currently
          saved within the system.
        </div>

        <hr />

        <div className="flex flex-col gap-2">
          <label className="grid grid-cols-[100px_1fr] gap-2 items-start mt-2">
            <span className="mt-1">Structures to update:</span>
            <ul>
              {structures && structures.map((item, i) => (
                <li key={i}>{item.structureType || 'Unknown Type'} - {item.name}</li>
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
            // onSelect={e => handleSelectOwner(e.value)}
            />
          </label>
        </div>

      </div>

      <div className="flex justify-end items-center gap-2 mt-4">
        <WdButton label="Save" className="p-button-sm" onClick={() => { console.log("save button clicked") }} />
      </div>
    </Dialog>
  );
};
