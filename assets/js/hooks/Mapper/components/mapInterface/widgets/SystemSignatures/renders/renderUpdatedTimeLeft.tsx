import { SystemSignature } from '@/hooks/Mapper/types';
import { TimeLeft } from '@/hooks/Mapper/components/ui-kit';

export const renderUpdatedTimeLeft = (row: SystemSignature) => {
  return (
    <div className="flex w-full items-center">
      <TimeLeft cDate={row.updated_at ? new Date(row.updated_at) : undefined} />
    </div>
  );
};
