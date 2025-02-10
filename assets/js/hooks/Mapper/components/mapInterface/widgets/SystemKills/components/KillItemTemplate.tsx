import { DetailedKill } from '@/hooks/Mapper/types/kills';
import { VirtualScrollerTemplateOptions } from 'primereact/virtualscroller';
import { KillRow } from './SystemKillsRow';
import clsx from 'clsx';

export function KillItemTemplate(
  systemNameMap: Record<string, string>,
  compact: boolean,
  onlyOneSystem: boolean,
  kill: DetailedKill,
  options: VirtualScrollerTemplateOptions,
) {
  const systemIdStr = String(kill.solar_system_id);
  const systemName = systemNameMap[systemIdStr] || `System ${systemIdStr}`;

  return (
    <div style={{ height: `${options.props.itemSize}px` }} className={clsx({ 'bg-gray-900': options.odd })}>
      <KillRow killDetails={kill} systemName={systemName} isCompact={compact} onlyOneSystem={onlyOneSystem} />
    </div>
  );
}
