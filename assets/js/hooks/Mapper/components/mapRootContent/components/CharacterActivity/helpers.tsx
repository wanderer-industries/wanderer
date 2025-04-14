import { CharacterCard } from '@/hooks/Mapper/components/ui-kit';
import { ActivitySummary } from '@/hooks/Mapper/types';

export const getRowClassName = () => ['text-xs', 'leading-tight'];

export const renderCharacterTemplate = (rowData: ActivitySummary) => {
  return <CharacterCard compact isOwn {...rowData.character} />;
};

export const renderValueTemplate = (rowData: ActivitySummary, field: keyof ActivitySummary) => {
  return <div className="tabular-nums w-full flex justify-center">{rowData[field] as number}</div>;
};
