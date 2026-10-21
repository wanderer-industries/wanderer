import type { ReactNode } from 'react';
import clsx from 'clsx';
import { WdButton } from './WdButton';
import { WdDialog } from './WdDialog';
import styles from './WdConfirmDialog.module.scss';

const DEFAULT_CONFIRM_LABEL = 'Confirm';
const DEFAULT_CANCEL_LABEL = 'Cancel';

export interface WdConfirmDialogProps {
  visible: boolean;
  header: ReactNode;
  children: ReactNode;
  confirmLabel?: string;
  cancelLabel?: string;
  confirmIcon?: string;
  loading?: boolean;
  className?: string;
  onConfirm(): void;
  onCancel(): void;
}

export const WdConfirmDialog = ({
  visible,
  header,
  children,
  confirmLabel = DEFAULT_CONFIRM_LABEL,
  cancelLabel = DEFAULT_CANCEL_LABEL,
  confirmIcon,
  loading = false,
  className,
  onConfirm,
  onCancel,
}: WdConfirmDialogProps) => {
  const handleHide = () => {
    if (!loading) {
      onCancel();
    }
  };

  const handleConfirm = () => {
    if (!loading) {
      onConfirm();
    }
  };

  const footer = (
    <div className="flex justify-end gap-2">
      <WdButton className="py-[4px]" text size="small" label={cancelLabel} disabled={loading} onClick={handleHide} />
      <WdButton
        className="py-[4px]"
        severity="danger"
        size="small"
        label={confirmLabel}
        icon={confirmIcon}
        disabled={loading}
        loading={loading}
        onClick={handleConfirm}
      />
    </div>
  );

  return (
    <WdDialog
      header={header}
      visible={visible}
      modal
      draggable={false}
      resizable={false}
      closable={!loading}
      closeOnEscape={!loading}
      focusOnShow={false}
      className={clsx(styles.dialog, className)}
      footer={footer}
      onHide={handleHide}
    >
      <div className="text-sm text-stone-300">{children}</div>
    </WdDialog>
  );
};
