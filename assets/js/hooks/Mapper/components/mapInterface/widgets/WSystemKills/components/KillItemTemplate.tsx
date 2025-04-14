import { DetailedKill } from '@/hooks/Mapper/types/kills';
import { VirtualScrollerTemplateOptions } from 'primereact/virtualscroller';
import { KillRowDetail } from '@/hooks/Mapper/components/mapInterface/widgets/WSystemKills/components/KillRowDetail.tsx';
import clsx from 'clsx';
import { getSystemStaticInfo } from '@/hooks/Mapper/mapRootProvider/hooks/useLoadSystemStatic';

export const KillItemTemplate = (
  onlyOneSystem: boolean,
  kill: DetailedKill,
  options: VirtualScrollerTemplateOptions,
) => {
  const systemName = getSystemStaticInfo(kill.solar_system_id)?.solar_system_name || `System ${kill.solar_system_id}`;

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
