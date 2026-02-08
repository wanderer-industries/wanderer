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

export function utcToCalendarDate(utcIso: string): Date {
  // Parse ISO components manually to avoid browser quirks with
  // 6-digit microsecond precision from Elixir's :utc_datetime_usec.
  const m = utcIso.match(/^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})/);
  if (m) {
    const [, yr, mo, dy, hr, mi, sc] = m;
    return new Date(+yr, +mo - 1, +dy, +hr, +mi, +sc);
  }
  // Fallback for non-ISO strings
  const d = new Date(utcIso);
  return new Date(d.getTime() + d.getTimezoneOffset() * 60_000);
}

export function calendarDateToUtcIso(localDate: Date): string {
  // Read local-time components (which represent EVE/UTC time) and
  // build the ISO string directly — no timezone arithmetic needed.
  const pad = (n: number) => String(n).padStart(2, '0');
  return (
    `${localDate.getFullYear()}-${pad(localDate.getMonth() + 1)}-${pad(localDate.getDate())}` +
    `T${pad(localDate.getHours())}:${pad(localDate.getMinutes())}:${pad(localDate.getSeconds())}.000Z`
  );
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
