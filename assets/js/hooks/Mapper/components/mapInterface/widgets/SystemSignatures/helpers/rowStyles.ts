import clsx from 'clsx';
import { SignatureGroup } from '@/hooks/Mapper/types';
import { ExtendedSystemSignature } from './contentHelpers';
import { getRowBackgroundColor } from './getRowBackgroundColor';
import classes from './rowStyles.module.scss';

export function getSignatureRowClass(
  row: ExtendedSystemSignature,
  selectedSignatures: ExtendedSystemSignature[],
  colorByType?: boolean,
): string {
  const isSelected = selectedSignatures.some(s => s.eve_id === row.eve_id);

  if (isSelected) {
    return clsx(
      classes.TableRowCompact,
      'p-selectable-row',
      'bg-amber-500/50 hover:bg-amber-500/70 transition duration-200 text-xs',
    );
  }

  if (row.pendingDeletion) {
    return clsx(classes.TableRowCompact, 'p-selectable-row', classes.pendingDeletion);
  }

  // Apply color by type styling if enabled
  if (colorByType) {
    if (row.group === SignatureGroup.Wormhole) {
      return clsx(
        classes.TableRowCompact,
        'p-selectable-row',
        'bg-blue-400/20 hover:bg-blue-400/20 transition duration-200 text-xs',
      );
    }

    if (row.group === SignatureGroup.CosmicSignature) {
      return clsx(
        classes.TableRowCompact,
        'p-selectable-row',
        'bg-red-400/20 hover:bg-red-400/20 transition duration-200 text-xs',
      );
    }

    if (
      row.group === SignatureGroup.RelicSite ||
      row.group === SignatureGroup.DataSite ||
      row.group === SignatureGroup.GasSite ||
      row.group === SignatureGroup.OreSite ||
      row.group === SignatureGroup.CombatSite
    ) {
      return clsx(
        classes.TableRowCompact,
        'p-selectable-row',
        'bg-green-400/20 hover:bg-green-400/20 transition duration-200 text-xs',
      );
    }

    // Default for color by type - apply same color as CosmicSignature (red) and small text size
    return clsx(
      classes.TableRowCompact,
      'p-selectable-row',
      'bg-red-400/20 hover:bg-red-400/20 transition duration-200 text-xs',
    );
  }

  // Original styling when color by type is disabled
  return clsx(
    classes.TableRowCompact,
    'p-selectable-row',
    !row.pendingDeletion && getRowBackgroundColor(row.inserted_at ? new Date(row.inserted_at) : undefined),
    !row.pendingDeletion && 'hover:bg-purple-400/20 transition duration-200',
  );
}
