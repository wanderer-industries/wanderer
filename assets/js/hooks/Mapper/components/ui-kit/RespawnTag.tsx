import { Respawn } from '@/hooks/Mapper/types';
import clsx from 'clsx';

export const WORMHOLE_SPAWN_CLASSES_BG = {
  [Respawn.static]: 'bg-lime-400/80 text-stone-950',
  [Respawn.wandering]: 'bg-stone-800',
  [Respawn.reverse]: 'bg-blue-400 text-stone-950',
};

type RespawnTagProps = { value: string };
export const RespawnTag = ({ value }: RespawnTagProps) => (
  <span
    className={clsx(
      'px-[6px] py-[0px] rounded text-stone-300 text-[12px] font-[500] border border-stone-700',
      WORMHOLE_SPAWN_CLASSES_BG[value as Respawn],
    )}
  >
    {value}
  </span>
);
