import { SolarSystemRawType } from '@/hooks/Mapper/types/system.ts';
import { convertSystem2Node } from './convertSystem2Node.ts';

function system(locked: boolean): SolarSystemRawType {
  return {
    id: 'system',
    position: { x: 0, y: 0 },
    locked,
  } as SolarSystemRawType;
}

describe('convertSystem2Node', () => {
  test('makes an unlocked system draggable', () => {
    expect(convertSystem2Node(system(false)).draggable).toBe(true);
  });

  test('keeps a locked system non-draggable in every map mode', () => {
    expect(convertSystem2Node(system(true)).draggable).toBe(false);
  });
});
