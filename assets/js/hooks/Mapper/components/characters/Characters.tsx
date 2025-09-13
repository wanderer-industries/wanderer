import { emitMapEvent } from '@/hooks/Mapper/events';
import { isDocked } from '@/hooks/Mapper/helpers/isDocked.ts';
import { useMapRootState } from '@/hooks/Mapper/mapRootProvider';
import { CharacterTypeRaw } from '@/hooks/Mapper/types';
import { Commands, OutCommand } from '@/hooks/Mapper/types/mapHandlers.ts';
import { useAutoAnimate } from '@formkit/auto-animate/react';
import clsx from 'clsx';
import { PrimeIcons } from 'primereact/api';
import { useCallback } from 'react';
import classes from './Characters.module.scss';
interface CharactersProps {
  data: CharacterTypeRaw[];
}

export const Characters = ({ data }: CharactersProps) => {
  const [parent] = useAutoAnimate();

  const {
    outCommand,
    data: { mainCharacterEveId, followingCharacterEveId },
  } = useMapRootState();

  const handleSelect = useCallback(async (character: CharacterTypeRaw) => {
    if (!character) {
      return;
    }

    await outCommand({
      type: OutCommand.startTracking,
      data: { character_eve_id: character.eve_id },
    });
    emitMapEvent({
      name: Commands.centerSystem,
      data: character.location?.solar_system_id?.toString(),
    });
  }, []);

  const items = data.map(character => (
    <li
      key={character.eve_id}
      className="flex flex-col items-center justify-center"
      onClick={() => handleSelect(character)}
    >
      <div
        className={clsx(
          'overflow-hidden relative',
          'flex w-[35px] h-[35px] rounded-[4px] border-[1px] border-solid bg-transparent cursor-pointer',
          'transition-colors duration-250 hover:bg-stone-300/90',
          {
            ['border-stone-800/90']: !character.online,
            ['border-lime-600/70']: character.online,
          },
        )}
        title={character.tracking_paused ? `${character.name} - Tracking Paused (click to resume)` : character.name}
      >
        {character.tracking_paused && (
          <>
            <span
              className={clsx(
                'absolute flex flex-col  p-[2px]  top-[0px] left-[0px] w-[35px] h-[35px]',
                'text-yellow-500 text-[9px] z-10 bg-gray-800/40',
                'pi',
                PrimeIcons.PAUSE,
              )}
            />
          </>
        )}
        {mainCharacterEveId === character.eve_id && (
          <span
            className={clsx(
              'absolute top-[2px] left-[22px] w-[9px] h-[9px]',
              'text-yellow-500 text-[9px] rounded-[1px] z-10',
              'pi',
              PrimeIcons.STAR_FILL,
            )}
          />
        )}

        {followingCharacterEveId === character.eve_id && (
          <span
            className={clsx(
              'absolute top-[23px] left-[22px] w-[10px] h-[10px]',
              'text-sky-300 text-[10px] rounded-[1px] z-10',
              'pi pi-angle-double-right',
            )}
          />
        )}
        {isDocked(character.location) && <div className={classes.Docked} />}
        <div
          className={clsx(
            'flex w-full h-full bg-transparent cursor-pointer',
            'bg-center bg-no-repeat bg-[length:100%]',
            'transition-opacity',
            'shadow-[inset_0_1px_6px_1px_#000000]',
            {
              ['opacity-60']: !character.online,
              ['opacity-100']: character.online,
            },
          )}
          style={{ backgroundImage: `url(https://images.evetech.net/characters/${character.eve_id}/portrait)` }}
        ></div>
      </div>
    </li>
  ));

  return (
    <ul className="flex gap-1 characters" id="characters" ref={parent}>
      {items}
    </ul>
  );
};
