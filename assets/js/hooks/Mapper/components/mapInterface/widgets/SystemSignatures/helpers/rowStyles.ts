import { ExtendedSystemSignature, SignatureGroup } from '@/hooks/Mapper/types';
import clsx from 'clsx';
import { getRowBackgroundColor } from './getRowBackgroundColor';
import classes from './rowStyles.module.scss';
import { GlowingRowInfo } from '../hooks/types';

const BASE_ROW_CLASSES = 'transition duration-200 my-2 hover:bg-purple-400/20';
const SELECTED_ROW_CLASSES = '!bg-white/20 hover:!bg-white/25';
const DELETED_ROW_CLASSES = 'bg-red-400/40 hover:bg-red-400/50';
const NEW_ROW_GLOW_CLASSES = 'duration-500 bg-lime-500/30 hover:bg-lime-500/50';
const EXISTING_ROW_GLOW_CLASSES = 'duration-500 bg-orange-200/10 hover:bg-orange-200/50';

const getColorByTypeClasses = (row: ExtendedSystemSignature): string => {
  switch (row.group) {
    case SignatureGroup.CosmicSignature:
      return '[&_td:nth-child(-n+3)]:text-rose-400 [&_td:nth-child(-n+3)]:hover:text-rose-300';
    case SignatureGroup.Wormhole:
      return '[&_td:nth-child(-n+3)]:text-sky-300 [&_td:nth-child(-n+3)]:hover:text-sky-200';
    case SignatureGroup.CombatSite:
    case SignatureGroup.RelicSite:
    case SignatureGroup.DataSite:
    case SignatureGroup.GasSite:
    case SignatureGroup.OreSite:
      return '[&_td:nth-child(-n+4)]:text-lime-400 [&_td:nth-child(-n+4)]:hover:text-lime-300';
    default:
      return '[&_td:nth-child(-n+3)]:text-rose-400';
  }
};

export function getSignatureRowClass(
  row: ExtendedSystemSignature,
  selectedSignatures: ExtendedSystemSignature[],
  colorByType?: boolean,
  glowingRows?: Map<string, GlowingRowInfo>,
  systemId?: string,
): string {
  const isSelected = selectedSignatures.some(s => s.eve_id === row.eve_id);

  const baseCls = [
    classes.TableRowCompact,
    getRowBackgroundColor(row.inserted_at ? new Date(row.inserted_at) : undefined),
    BASE_ROW_CLASSES,
  ];
  const colorByTypeClasses = colorByType ? getColorByTypeClasses(row) : undefined;

  if (isSelected) {
    return clsx(baseCls, colorByTypeClasses, SELECTED_ROW_CLASSES);
  }

  if (row.deleted) {
    return clsx(baseCls, DELETED_ROW_CLASSES);
  }

  const glowInfo = glowingRows?.get(row.eve_id);
  let glowClasses: string | undefined;
  if (glowInfo && glowInfo.systemId === systemId) {
    glowClasses = glowInfo.isNew ? NEW_ROW_GLOW_CLASSES : EXISTING_ROW_GLOW_CLASSES;
  }

  return clsx(baseCls, colorByTypeClasses, glowClasses);
}
