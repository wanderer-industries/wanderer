import { DetailedKill } from '@/hooks/Mapper/types/kills';
import { VirtualScrollerTemplateOptions } from 'primereact/virtualscroller';
import { KillRowDetail } from '@/hooks/Mapper/components/mapInterface/widgets/WSystemKills/components/KillRowDetail.tsx';
import clsx from 'clsx';

export const KillItemTemplate = (
  systemNameMap: Record<string, string>,
  onlyOneSystem: boolean,
  kill: DetailedKill,
  options: VirtualScrollerTemplateOptions,
) => {
  const systemIdStr = String(kill.solar_system_id);
  const systemName = systemNameMap[systemIdStr] || `System ${systemIdStr}`;

  return (
    <div style={{ height: `${options.props.itemSize}px` }}>
      <KillRowDetail
        killDetails={kill}
        systemName={systemName}
        onlyOneSystem={onlyOneSystem}
        className={clsx(options.odd && 'bg-stone-800/50')}
      />
    </div>
  );
};
