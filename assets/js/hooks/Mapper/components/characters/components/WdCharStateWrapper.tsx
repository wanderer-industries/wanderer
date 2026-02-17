import clsx from 'clsx';
import { PrimeIcons } from 'primereact/api';
import { isDocked } from '@/hooks/Mapper/helpers/isDocked.ts';
import classes from './WdCharStateWrapper.module.scss';
import { WithChildren } from '@/hooks/Mapper/types/common.ts';
import { LocationRaw } from '@/hooks/Mapper/types';

type WdCharStateWrapperProps = {
  eve_id: string;
  isExpired?: boolean;
  isMain?: boolean;
  isFollowing?: boolean;
  location: LocationRaw | null;
  isOnline: boolean;
} & WithChildren;

export const WdCharStateWrapper = ({
  location,
  isOnline,
  isMain,
  isFollowing,
  isExpired,
  children,
}: WdCharStateWrapperProps) => {
  return (
    <div
      className={clsx(
        'overflow-hidden relative',
        'flex w-[35px] h-[35px] rounded-[4px] border-[1px] border-solid bg-transparent cursor-pointer',
        'transition-colors duration-250 hover:bg-stone-300/90',
        {
          ['border-stone-800/90']: !isExpired && !isOnline,
          ['border-lime-600/70']: !isExpired && isOnline,
          ['border-red-600/70']: isExpired,
        },
      )}
    >
      {isMain && (
        <span
          className={clsx(
            'absolute top-[2px] left-[22px] w-[9px] h-[9px]',
            'text-yellow-500 text-[9px] rounded-[1px] z-10',
            'pi',
            PrimeIcons.STAR_FILL,
          )}
        />
      )}
      {isFollowing && (
        <span
          className={clsx(
            'absolute top-[23px] left-[22px] w-[10px] h-[10px]',
            'text-sky-300 text-[10px] rounded-[1px] z-10',
            'pi pi-angle-double-right',
          )}
        />
      )}
      {isDocked(location) && <div className={classes.Docked} />}
      {isExpired && (
        <span
          className={clsx(
            'absolute top-[4px] left-[4px] w-[10px] h-[10px]',
            'text-red-400 text-[10px] rounded-[1px] z-10',
            'pi pi-exclamation-triangle',
          )}
        />
      )}

      {children}
    </div>
  );
};
