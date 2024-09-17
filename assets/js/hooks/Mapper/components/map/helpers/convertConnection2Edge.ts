import { SolarSystemConnection } from '@/hooks/Mapper/types/connection.ts';

export const convertConnection2Edge = (conn: SolarSystemConnection) => {
  return {
    sourceHandle: 'c',
    targetHandle: 'a',
    type: 'floating',
    label: 'updatable edge',

    id: conn.id,
    source: conn.source,
    target: conn.target,
    data: conn,
  };
};
