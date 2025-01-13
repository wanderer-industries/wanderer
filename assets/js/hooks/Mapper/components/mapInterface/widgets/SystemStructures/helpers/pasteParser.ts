import { StructureItem } from './structureTypes';
import { parseThreeLineSnippet, parseFormatOneLine, matchesThreeLineSnippet } from './parserHelper';

export function processSnippetText(rawText: string, existingStructures: StructureItem[]): StructureItem[] {
  if (!rawText) {
    return existingStructures.slice();
  }

  const lines = rawText
    .split(/\r?\n/)
    .map(line => line.trim())
    .filter(Boolean);

  if (lines.length === 3 && matchesThreeLineSnippet(lines)) {
    return applyThreeLineSnippet(lines, existingStructures);
  } else {
    return applySingleLineParse(lines, existingStructures);
  }
}

function applyThreeLineSnippet(snippetLines: string[], existingStructures: StructureItem[]): StructureItem[] {
  const updatedList = [...existingStructures];
  const snippetItem = parseThreeLineSnippet(snippetLines);

  const existingIndex = updatedList.findIndex(s => s.name.trim() === snippetItem.name.trim());

  if (existingIndex !== -1) {
    const existing = updatedList[existingIndex];
    updatedList[existingIndex] = {
      ...existing,
      status: snippetItem.status,
      endTime: snippetItem.endTime,
    };
  }

  return updatedList;
}

function applySingleLineParse(lines: string[], existingStructures: StructureItem[]): StructureItem[] {
  const updatedList = [...existingStructures];
  const newItems: StructureItem[] = [];

  for (const line of lines) {
    const item = parseFormatOneLine(line);
    if (!item) continue;

    const isDuplicate = updatedList.some(
      s => s.structureTypeId === item.structureTypeId && s.name.trim() === item.name.trim(),
    );
    if (!isDuplicate) {
      newItems.push(item);
    }
  }

  return [...updatedList, ...newItems];
}
