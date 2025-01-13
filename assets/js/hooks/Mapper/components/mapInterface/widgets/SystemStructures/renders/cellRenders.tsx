import { StructureItem } from '../helpers';
import { TimerCell } from './TimerCell';

export function renderTimerCell(row: StructureItem) {
  return <TimerCell endTime={row.endTime} status={row.status} />;
}

export function renderOwnerCell(row: StructureItem) {
  return (
    <div className="flex items-center gap-2">
      {row.ownerId && (
        <img
          src={`https://images.evetech.net/corporations/${row.ownerId}/logo?size=32`}
          alt="corp icon"
          className="w-5 h-5 object-contain"
        />
      )}
      <span>{row.ownerTicker || row.ownerName}</span>
    </div>
  );
}

export function renderTypeCell(row: StructureItem) {
  return (
    <div className="flex items-center gap-1">
      {row.structureTypeId && (
        <img
          src={`https://images.evetech.net/types/${row.structureTypeId}/icon`}
          alt="icon"
          className="w-5 h-5 object-contain"
        />
      )}
      <span>{row.structureType ?? ''}</span>
    </div>
  );
}
