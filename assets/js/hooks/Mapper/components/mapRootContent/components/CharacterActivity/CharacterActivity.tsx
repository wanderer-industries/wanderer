import { Dialog } from 'primereact/dialog';
import { CharacterActivityContent } from '@/hooks/Mapper/components/mapRootContent/components/CharacterActivity/CharacterActivityContent.tsx';

interface CharacterActivityProps {
  visible: boolean;
  onHide: () => void;
}

export const CharacterActivity = ({ visible, onHide }: CharacterActivityProps) => {
  return (
    <Dialog header="Character Activity" visible={visible} className="w-[550px]" onHide={onHide} dismissableMask>
      <div className="w-full h-[500px] flex flex-col overflow-hidden p-0 m-0">
        <CharacterActivityContent />
      </div>
    </Dialog>
  );
};
