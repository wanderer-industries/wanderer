import { StructureStatus, StructureItem, STRUCTURE_TYPE_MAP } from './structureTypes';
import { formatToISO } from './structureUtils';

// Up to you if you'd like to keep a separate constant here or not
export const statusesRequiringTimer: StructureStatus[] = ['Anchoring', 'Reinforced'];

/**
 * parseFormatOneLine(line):
 *  - Splits by tabs
 *  - First col => structureTypeId
 *  - Second col => rawName
 *  - Third col => structureTypeName
 */
export function parseFormatOneLine(line: string): StructureItem | null {
  const columns = line
    .split('\t')
    .map(c => c.trim())
    .filter(Boolean);

  // Expecting e.g. "35832   J214811 - SomeName    Astrahus"
  if (columns.length < 3) {
    return null;
  }

  const [rawTypeId, rawName, rawTypeName] = columns;

  if (columns.length != 4) {
    return null;
  }

  if (!STRUCTURE_TYPE_MAP[rawTypeId]) {
    return null;
  }

  // in some localizations (like russian) there is an option called "mark names with *"
  // The example output will be "35826	Itamo - Research & Production	Azbel*	609 м"
  // so, let's fix this
  const localizationFixedName = rawTypeName.replace("*", "");

  if (localizationFixedName != STRUCTURE_TYPE_MAP[rawTypeId]) {
    return null;
  }

  const name = rawName.replace(/^J\d{6}\s*-\s*/, '').trim();

  return {
    id: crypto.randomUUID(),
    structureTypeId: rawTypeId,
    structureType: rawTypeName,
    name,
    ownerName: '',
    notes: '',
    status: 'Powered', // Default
    endTime: '', // No timer by default
  };
}

export function matchesThreeLineSnippet(lines: string[]): boolean {
  if (lines.length < 3) return false;
  return /until\s+\d{4}\.\d{2}\.\d{2}/i.test(lines[2]);
}

/**
 * parseThreeLineSnippet:
 *  - Example lines:
 *    line1: "J214811 - Folgers"
 *    line2: "1,475 km"
 *    line3: "Reinforced until 2025.01.13 23:51"
 */
export function parseThreeLineSnippet(lines: string[]): StructureItem {
  const [line1, , line3] = lines;

  let status: StructureStatus = 'Reinforced';
  let endTime: string | undefined;

  // e.g. "Reinforced until 2025.01.13 23:27"
  const match = line3.match(/^(?<stat>\w+)\s+until\s+(?<dateTime>[\d.]+\s+[\d:]+)/i);

  if (match?.groups?.stat) {
    const candidateStatus = match.groups.stat as StructureStatus;
    if (statusesRequiringTimer.includes(candidateStatus)) {
      status = candidateStatus;
    }
  }
  if (match?.groups?.dateTime) {
    let dt = match.groups.dateTime.trim().replace(/\./g, '-'); // "2025-01-13 23:27"
    dt = dt.replace(' ', 'T'); // "2025-01-13T23:27"
    endTime = formatToISO(dt); // => "2025-01-13T23:27:00Z"
  }

  return {
    id: crypto.randomUUID(),
    name: line1.replace(/^J\d{6}\s*-\s*/, '').trim(),
    status,
    endTime,
  };
}
