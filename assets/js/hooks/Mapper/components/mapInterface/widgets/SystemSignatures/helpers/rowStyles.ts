import clsx from 'clsx';
import { ExtendedSystemSignature } from './contentHelpers';
import { getRowBackgroundColor } from './getRowBackgroundColor';
import classes from './rowStyles.module.scss';

export function getSignatureRowClass(
  row: ExtendedSystemSignature,
  selectedSignatures: ExtendedSystemSignature[],
): string {
  const isSelected = selectedSignatures.some(s => s.eve_id === row.eve_id);

  return clsx(
    classes.TableRowCompact,
    'p-selectable-row',
    isSelected && 'bg-amber-500/50 hover:bg-amber-500/70 transition duration-200',
    !isSelected && row.pendingDeletion && classes.pendingDeletion,
    !isSelected &&
      !row.pendingDeletion &&
      getRowBackgroundColor(row.inserted_at ? new Date(row.inserted_at) : undefined),
    !isSelected && !row.pendingDeletion && 'hover:bg-purple-400/20 transition duration-200',
  );
}
