import { useMemo, useState } from 'react';
import { Dialog } from 'primereact/dialog';
import { DataTable } from 'primereact/datatable';
import { Column } from 'primereact/column';
import { useMapRootState } from '@/hooks/Mapper/mapRootProvider';
import { WormholeDataRaw } from '@/hooks/Mapper/types';
import { RespawnTag, WHClassView } from '@/hooks/Mapper/components/ui-kit';
import { kgToTons } from '@/hooks/Mapper/utils/kgToTons.ts';
import { WORMHOLE_CLASS_STYLES, WORMHOLES_ADDITIONAL_INFO } from '@/hooks/Mapper/components/map/constants.ts';
import clsx from 'clsx';
import { InputText } from 'primereact/inputtext';
import { IconField } from 'primereact/iconfield';
import { InputIcon } from 'primereact/inputicon';

const renderSpawns = (w: WormholeDataRaw) => (
  <div className="flex gap-1 flex-wrap">
    {w.src.map(s => {
      const group = s.split('-')[0];
      const info = WORMHOLES_ADDITIONAL_INFO[group];

      if (!info) {
        return (
          <span
            key={s}
            className="px-[4px] py-[1px] rounded bg-stone-800 text-stone-300 text-xs border border-stone-700"
          >
            {s}
          </span>
        );
      }

      const cls = WORMHOLE_CLASS_STYLES[String(info.wormholeClassID)] || '';
      const label = `${info.shortName}`;
      return (
        <span
          key={s}
          className={clsx(cls, 'px-[4px] py-[1px] rounded text-xs border border-stone-700 bg-stone-900/40')}
        >
          {label}
        </span>
      );
    })}
  </div>
);

const renderName = (w: WormholeDataRaw) => (
  <div className="flex items-center gap-2">
    <WHClassView
      whClassName={w.name}
      noOffset
      useShortTitle
      classNameWh="overflow-hidden text-ellipsis whitespace-nowrap"
    />
  </div>
);

const renderRespawn = (w: WormholeDataRaw) => (
  <div className="flex gap-1 flex-wrap">
    {w.respawn.map(r => (
      <RespawnTag key={r} value={r} />
    ))}
  </div>
);

export interface WormholeSignaturesDialogProps {
  visible: boolean;
  onHide: () => void;
}

export const WormholeSignaturesDialog = ({ visible, onHide }: WormholeSignaturesDialogProps) => {
  const {
    data: { wormholes },
  } = useMapRootState();

  const [filter, setFilter] = useState('');

  const filtered = useMemo(() => {
    const q = filter.trim().toLowerCase();

    if (!q) return wormholes;

    return wormholes.filter(w => {
      const destInfo = WORMHOLES_ADDITIONAL_INFO[w.dest];
      const spawnsLabels = w.src
        .map(s => {
          const group = s.split('-')[0];
          const info = WORMHOLES_ADDITIONAL_INFO[group];
          if (!info) return s;
          return `${info.title} ${info.shortName}`.trim();
        })
        .join(' ');

      return [
        w.name,
        destInfo?.title,
        destInfo?.shortName,
        spawnsLabels,
        String(w.total_mass),
        String(w.max_mass_per_jump),
        w.lifetime,
        w.respawn.join(','),
      ]
        .filter(Boolean)
        .join(' ')
        .toLowerCase()
        .includes(q);
    });
  }, [wormholes, filter]);

  return (
    <Dialog
      header="Wormholes Reference"
      visible={visible}
      draggable={false}
      resizable={false}
      className="w-[950px] h-[600px]"
      onHide={onHide}
      contentClassName="!p-0 flex flex-col h-full"
    >
      <div className="p-3 flex items-center justify-between gap-2 border-b border-stone-800">
        <div className="font-semibold text-sm text-stone-200">Reference list of all wormhole types</div>
        <IconField iconPosition="right">
          <InputIcon
            className={clsx('pi pi-times', {
              ['cursor-pointer text-stone-400 hover:text-stone-200']: filter,
              ['text-stone-700 opacity-50 cursor-default']: !filter,
            })}
            onClick={() => filter && setFilter('')}
            role="button"
            aria-label="Clear search"
            aria-disabled={!filter}
            title={filter ? 'Clear' : 'Nothing to clear'}
          />
          <InputText className="w-64" placeholder="Search" value={filter} onChange={e => setFilter(e.target.value)} />
        </IconField>
      </div>

      <div className="flex-1 p-3 overflow-x-hidden">
        <DataTable value={filtered} size="small" scrollable scrollHeight="flex" stripedRows>
          <Column header="Type" body={renderName} className="w-[160px]" bodyClassName="whitespace-normal break-words" />
          <Column header="Spawns In" body={renderSpawns} bodyClassName="whitespace-normal break-words text-[13px]" />
          <Column
            field="lifetime"
            header="Lifetime"
            className="w-[90px]"
            bodyClassName="whitespace-normal break-words text-[13px]"
          />
          <Column
            header="Total Mass"
            className="w-[120px]"
            body={(w: WormholeDataRaw) => kgToTons(w.total_mass)}
            bodyClassName="whitespace-normal break-words text-[13px]"
          />
          <Column
            header="Max/jump"
            className="w-[120px]"
            body={(w: WormholeDataRaw) => kgToTons(w.max_mass_per_jump)}
            bodyClassName="whitespace-normal break-words text-[13px]"
          />
          <Column
            header="Respawn"
            className="w-[150px]"
            body={renderRespawn}
            bodyClassName="whitespace-normal break-words text-[13px]"
          />
        </DataTable>
      </div>
    </Dialog>
  );
};
