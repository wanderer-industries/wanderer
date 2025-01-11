import type { NodeChange } from 'reactflow';

export function validateChanges(changes: NodeChange[]): NodeChange[] {
  return changes.filter((ch) => {
    if (ch.type === 'position') {
      const { x, y } = ch.position ?? {};
      if (x == null || y == null || Number.isNaN(x) || Number.isNaN(y)) {
        console.debug('Skipping invalid position change:', ch, new Error().stack);
        return false;
      }
    }

    return true;
  });
}

export function logChanges(changes: NodeChange[]): void {
  const loggingChanges = changes.filter((ch) => ch.type !== 'select');
  
  if (loggingChanges.length === 0) {
    return;
  }

  const minimalLines = loggingChanges
    .map((ch) => {
      switch (ch.type) {
        case 'reset': {
          const { x, y } = ch.item?.position ?? {};
          return `reset ${ch.item?.id} (${x}, ${y})`;
        }
        case 'position': {
          const { x, y } = ch.position ?? {};
          return `pos - ${ch.id} (${x}, ${y})`;
        }
        default:
          return undefined;
      }
    })
    .filter(Boolean) as string[];

  if (minimalLines.length > 0) {
    console.debug(`handle node change -> ${minimalLines.join('; ')}`);
  }
}
