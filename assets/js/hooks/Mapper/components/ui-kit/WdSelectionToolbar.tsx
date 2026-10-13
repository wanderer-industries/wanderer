import clsx from 'clsx';
import { PrimeIcons } from 'primereact/api';
import { ConfirmPopup } from 'primereact/confirmpopup';

import { useConfirmPopup } from '@/hooks/Mapper/hooks';
import { WdImgButton } from './WdImgButton';
import { TooltipPosition } from './WdTooltip';

const COPY_TOOLTIP = { content: 'Copy selected', position: TooltipPosition.top };
const DELETE_TOOLTIP = { content: 'Delete selected', position: TooltipPosition.top };

export interface WdSelectionToolbarProps {
  selectedCount: number;
  onCopy?: () => void;
  onDelete?: () => void;
  className?: string;
}

export const WdSelectionToolbar = ({ selectedCount, onCopy, onDelete, className }: WdSelectionToolbarProps) => {
  const hasSelection = selectedCount > 0;
  const canCopy = hasSelection && Boolean(onCopy);
  const canDelete = hasSelection && Boolean(onDelete);
  const { cfShow, cfHide, cfVisible, cfRef } = useConfirmPopup();

  return (
    <>
      <div
        className={clsx(
          'flex h-6 flex-none items-center justify-between border-b border-stone-700/60 px-2 text-xs',
          className,
        )}
      >
        <span className="text-stone-400">
          Selected:{' '}
          <span className={clsx('font-semibold tabular-nums', hasSelection ? 'text-slate-100' : 'text-stone-500')}>
            {selectedCount}
          </span>
        </span>

        <div className="flex max-h-3 items-center gap-2.5 text-gray-200">
          <WdImgButton
            className={PrimeIcons.COPY}
            aria-label="Copy selected"
            tooltip={COPY_TOOLTIP}
            disabled={!canCopy}
            onClick={onCopy}
          />
          <WdImgButton
            className={clsx(PrimeIcons.TRASH, {
              'text-red-400 hover:text-red-300': canDelete,
              'text-gray-200': !canDelete,
            })}
            aria-label="Delete selected"
            tooltip={DELETE_TOOLTIP}
            disabled={!canDelete}
            onClick={cfShow}
          />
        </div>
      </div>

      <ConfirmPopup
        target={cfRef.current}
        visible={cfVisible}
        onHide={cfHide}
        message="Are you sure you want to delete?"
        icon="pi pi-exclamation-triangle"
        accept={onDelete}
      />
    </>
  );
};
