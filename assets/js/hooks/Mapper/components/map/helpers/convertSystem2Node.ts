import { SolarSystemRawType } from '@/hooks/Mapper/types/system.ts';
import { Node } from 'reactflow';

export const convertSystem2Node = (sys: SolarSystemRawType): Node => {
  return {
    type: 'custom',
    width: 130,
    height: 34,
    id: sys.id,
    position: sys.position,
    data: sys,
    draggable: !sys.locked,
    deletable: !sys.locked,
  };
};
