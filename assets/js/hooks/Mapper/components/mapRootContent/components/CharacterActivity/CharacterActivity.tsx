import { Dialog } from 'primereact/dialog';
import { CharacterActivityContent } from '@/hooks/Mapper/components/mapRootContent/components/CharacterActivity/CharacterActivityContent.tsx';

interface CharacterActivityProps {
  visible: boolean;
  onHide: () => void;
}

export const CharacterActivity = ({ visible, onHide }: CharacterActivityProps) => {
  return (
    <Dialog
      header="Character Activity"
      visible={visible}
      className="w-[550px] max-h-[90vh]"
      onHide={onHide}
      dismissableMask
      contentClassName="p-0 h-full flex flex-col"
    >
      <CharacterActivityContent />
    </Dialog>
  );
};
