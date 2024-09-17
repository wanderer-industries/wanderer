import { useCallback } from 'react';
import clsx from 'clsx';
import { useAutoAnimate } from '@formkit/auto-animate/react';
import { useMapRootState } from '@/hooks/Mapper/mapRootProvider';
import { Commands } from '@/hooks/Mapper/types/mapHandlers.ts';
import { CharacterTypeRaw } from '@/hooks/Mapper/types';

const Characters = ({ data }: { data: CharacterTypeRaw[] }) => {
  const [parent] = useAutoAnimate();
  const { mapRef } = useMapRootState();

  const handleSelect = useCallback(
    (character: CharacterTypeRaw) => {
      mapRef.current?.command(Commands.selectSystem, character?.location?.solar_system_id?.toString());
    },
    [mapRef],
  );

  const items = data.map(character => (
    <li
      key={character.eve_id}
      className="flex flex-col items-center justify-center"
      onClick={() => handleSelect(character)}
    >
      <div className="tooltip tooltip-bottom" title={character.name}>
        <a
          className={clsx('wd-characters-icons wd-bg-default', { ['character-online']: character.online })}
          style={{ backgroundImage: `url(https://images.evetech.net/characters/${character.eve_id}/portrait)` }}
        ></a>
      </div>
    </li>
  ));

  return (
    <ul className="flex characters" id="characters" ref={parent}>
      {items}
    </ul>
  );
};

// eslint-disable-next-line react/display-name
export default Characters;
