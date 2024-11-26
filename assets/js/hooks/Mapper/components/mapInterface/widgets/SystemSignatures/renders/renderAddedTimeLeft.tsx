import { SystemSignature } from '@/hooks/Mapper/types';
import { TimeLeft } from '@/hooks/Mapper/components/ui-kit';

export const renderAddedTimeLeft = (row: SystemSignature) => {
  return (
    <div className="flex w-full items-center">
      <TimeLeft cDate={row.inserted_at ? new Date(row.inserted_at) : undefined} />
    </div>
  );
};
