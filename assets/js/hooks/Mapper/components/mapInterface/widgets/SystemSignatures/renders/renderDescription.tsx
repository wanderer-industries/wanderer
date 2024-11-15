import { SystemSignature } from '@/hooks/Mapper/types';

export const renderDescription = (row: SystemSignature) => {
  return <span title={row?.description}>{row?.description}</span>;
};
