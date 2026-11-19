import { SystemView } from '@/hooks/Mapper/components/ui-kit/SystemView';
import { WdButton } from '@/hooks/Mapper/components/ui-kit/WdButton.tsx';
import { WdDialog } from '@/hooks/Mapper/components/ui-kit/WdDialog.tsx';

export interface WdSystemSelectionDialogProps {
  visible: boolean;
  selectedSystemIds: number[];
  title?: string;
  onAdd: () => void;
  onRemove: (systemId: number) => void;
  onApply: () => void;
  onHide: () => void;
}

export const WdSystemSelectionDialog = ({
  visible,
  selectedSystemIds,
  title = 'Select systems',
  onAdd,
  onRemove,
  onApply,
  onHide,
}: WdSystemSelectionDialogProps) => {
  return (
    <WdDialog
      header={title}
      visible={visible}
      draggable={false}
      className="h-[460px] w-[420px]"
      contentClassName="min-h-0 flex-1 overflow-hidden !p-0"
      onHide={onHide}
    >
      <div className="flex h-full min-h-0 flex-col gap-3 p-3">
        <div className="flex justify-end">
          <WdButton label="Add system" icon="pi pi-plus" size="small" text className="px-1 py-[4px]" onClick={onAdd} />
        </div>

        <div className="min-h-0 flex-1 overflow-auto border border-stone-800 custom-scrollbar">
          {selectedSystemIds.map(systemId => (
            <div
              key={systemId}
              className="flex items-center justify-between border-b border-stone-800/80 py-1.5 pl-3 pr-2 text-xs hover:bg-stone-800/40"
            >
              <SystemView systemId={systemId.toString()} showCustomName hideRegion compact />
              <button
                type="button"
                className="pi pi-trash text-xs text-stone-500 hover:text-red-400"
                aria-label="Remove system"
                onClick={() => onRemove(systemId)}
              />
            </div>
          ))}
        </div>

        <div className="mt-auto flex shrink-0 justify-end gap-2 pt-1">
          <WdButton label="Cancel" size="small" text className="py-[4px]" onClick={onHide} />
          <WdButton label="Apply" size="small" outlined className="py-[4px]" onClick={onApply} />
        </div>
      </div>
    </WdDialog>
  );
};
