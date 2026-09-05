import { sortOnlineFunc } from '@/hooks/Mapper/components/hooks/useGetOwnOnlineCharacters.ts';
import { useMapRootState } from '@/hooks/Mapper/mapRootProvider';
import { WithChildren } from '@/hooks/Mapper/types/common.ts';
import clsx from 'clsx';
import { useMemo } from 'react';
import { Characters } from '../characters/Characters';

const Topbar = ({ children }: WithChildren) => {
  const {
    data: { characters, userCharacters },
  } = useMapRootState();

  const charsToShow = useMemo(() => {
    return characters.filter(x => userCharacters.includes(x.eve_id)).sort(sortOnlineFunc);
  }, [characters, userCharacters]);

  return (
    <nav
      className={clsx(
        'relative px-2 flex items-center justify-center min-w-0 h-12 pointer-events-auto',
        'border-b border-stone-800 bg-gray-800 bg-opacity-5',
        'bg-opacity-70 bg-neutral-900',
      )}
    >
      <div className="absolute left-1/2 top-1/2 -translate-x-1/2 -translate-y-1/2 text-white font-medium pointer-events-none">
        TNA-wanderer v260904-1
      </div>
      <span className="flex-1"></span>
      <span className="mr-2"></span>
      <div className="flex gap-1 items-center">
        <Characters data={charsToShow} />
      </div>

      {children}
    </nav>
  );
};

// eslint-disable-next-line react/display-name
export default Topbar;
