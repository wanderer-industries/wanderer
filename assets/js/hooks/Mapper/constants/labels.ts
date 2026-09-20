export type SystemLabelDefinition = {
  id: string;
  name: string;
  color: string;
};

export const DEFAULT_SYSTEM_LABELS: SystemLabelDefinition[] = [
  { id: 'a', name: 'A', color: '#2d803b' },
  { id: 'b', name: 'B', color: '#3d94af' },
  { id: 'c', name: 'C', color: '#3d94af' },
  { id: '1', name: '1', color: '#563daf' },
  { id: '2', name: '2', color: '#8f3daf' },
  { id: '3', name: '3', color: '#3d65af' },
];

export const UNKNOWN_LABEL_COLOR = '#4c4c4c';

export const getDefaultSystemLabels = (): SystemLabelDefinition[] => DEFAULT_SYSTEM_LABELS.map(x => ({ ...x }));

const isLabelDefinition = (val: unknown): val is SystemLabelDefinition => {
  if (!val || typeof val !== 'object') {
    return false;
  }

  const { id, name, color } = val as Record<string, unknown>;
  return typeof id === 'string' && typeof name === 'string' && typeof color === 'string';
};

/**
 * Remote settings are stored as free form JSON, so anything may come from the server -
 * fall back to defaults when the stored value is missing or malformed.
 */
export const parseSystemLabels = (raw: unknown): SystemLabelDefinition[] => {
  if (typeof raw === 'string') {
    try {
      return parseSystemLabels(JSON.parse(raw));
    } catch {
      return getDefaultSystemLabels();
    }
  }

  if (!Array.isArray(raw)) {
    return getDefaultSystemLabels();
  }

  // shortName used to be a separate badge field - drop it, the name is the badge now
  const labels = raw.filter(isLabelDefinition).map(({ id, name, color }) => ({ id: id.trim(), name, color }));

  if (labels.length === 0) {
    return getDefaultSystemLabels();
  }

  const seen = new Set<string>();
  return labels.filter(x => {
    if (x.id === '' || seen.has(x.id)) {
      return false;
    }

    seen.add(x.id);
    return true;
  });
};

/**
 * Ids are persisted on systems, so they must stay stable and unique inside one label set.
 */
export const createLabelId = (labels: SystemLabelDefinition[]): string => {
  const used = new Set(labels.map(x => x.id));

  for (let i = 0; i < 26; i++) {
    const id = String.fromCharCode(97 + i);
    if (!used.has(id)) {
      return id;
    }
  }

  let index = 1;
  while (used.has(`l${index}`)) {
    index++;
  }

  return `l${index}`;
};

export const getLabelDefinition = (labels: SystemLabelDefinition[], id: string): SystemLabelDefinition =>
  labels.find(x => x.id === id) ?? {
    id,
    name: id.toUpperCase(),
    color: UNKNOWN_LABEL_COLOR,
  };
