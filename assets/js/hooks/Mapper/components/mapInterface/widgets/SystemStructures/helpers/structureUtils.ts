import { StructureItem } from './structureTypes';

export function getActualStructures(oldList: StructureItem[], newList: StructureItem[]) {
  const oldMap = new Map(oldList.map(s => [s.id, s]));
  const newMap = new Map(newList.map(s => [s.id, s]));

  const added: StructureItem[] = [];
  const updated: StructureItem[] = [];
  const removed: StructureItem[] = [];

  for (const newItem of newList) {
    const oldItem = oldMap.get(newItem.id);
    if (!oldItem) {
      added.push(newItem);
    } else if (JSON.stringify(oldItem) !== JSON.stringify(newItem)) {
      updated.push(newItem);
    }
  }

  for (const oldItem of oldList) {
    if (!newMap.has(oldItem.id)) {
      removed.push(oldItem);
    }
  }

  return { added, updated, removed };
}

// eslint-disable-next-line @typescript-eslint/no-explicit-any
export function mapServerStructure(serverData: any): StructureItem {
  const { owner_id, owner_ticker, structure_type_id, structure_type, owner_name, end_time, system_id, ...rest } =
    serverData;

  return {
    ...rest,
    ownerId: owner_id,
    ownerTicker: owner_ticker,
    ownerName: owner_name,
    structureType: structure_type,
    structureTypeId: structure_type_id,
    endTime: end_time ?? '',
    systemId: system_id,
  };
}

export function formatToISO(datetimeLocal: string): string {
  if (!datetimeLocal) return '';

  // If missing seconds, add :00
  let iso = datetimeLocal;
  if (/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}$/.test(iso)) {
    iso += ':00';
  }
  // Ensure trailing 'Z'
  if (!iso.endsWith('Z')) {
    iso += 'Z';
  }
  return iso;
}
