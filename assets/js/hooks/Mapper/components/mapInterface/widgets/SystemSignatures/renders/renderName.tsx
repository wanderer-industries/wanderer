import { SystemSignature } from '@/hooks/Mapper/types';

export const renderName = (row: SystemSignature) => {
  return <span title={row.name}>{row.name}</span>;
};
