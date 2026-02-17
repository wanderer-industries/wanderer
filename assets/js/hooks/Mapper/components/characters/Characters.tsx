import { emitMapEvent } from '@/hooks/Mapper/events';
import { useMapRootState } from '@/hooks/Mapper/mapRootProvider';
import { CharacterTypeRaw } from '@/hooks/Mapper/types';
import { Commands, OutCommand } from '@/hooks/Mapper/types/mapHandlers.ts';
import { useAutoAnimate } from '@formkit/auto-animate/react';
import clsx from 'clsx';
import { useCallback } from 'react';
import {
  TooltipPosition,
  WdEveEntityPortrait,
  WdEveEntityPortraitSize,
  WdTooltipWrapper,
} from '@/hooks/Mapper/components/ui-kit';
import { WdCharStateWrapper } from '@/hooks/Mapper/components/characters/components/WdCharStateWrapper.tsx';

interface CharactersProps {
  data: CharacterTypeRaw[];
}

export const Characters = ({ data }: CharactersProps) => {
  const [parent] = useAutoAnimate();

  const {
    outCommand,
    data: { mainCharacterEveId, followingCharacterEveId, expiredCharacters },
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

  const items = data.map(character => {
    const isExpired = expiredCharacters.includes(character.eve_id);

    return (
      <li
        key={character.eve_id}
        className="flex flex-col items-center justify-center"
        onClick={() => handleSelect(character)}
      >
        <WdTooltipWrapper
          position={TooltipPosition.bottom}
          content={isExpired ? `Token is expired for ${character.name}` : character.name}
        >
          <WdCharStateWrapper
            eve_id={character.eve_id}
            location={character.location}
            isExpired={isExpired}
            isMain={mainCharacterEveId === character.eve_id}
            isFollowing={followingCharacterEveId === character.eve_id}
            isOnline={character.online}
          >
            <WdEveEntityPortrait
              eveId={character.eve_id}
              size={WdEveEntityPortraitSize.w33}
              className={clsx(
                'flex w-full h-full bg-transparent cursor-pointer',
                'bg-center bg-no-repeat bg-[length:100%]',
                'transition-opacity',
                'shadow-[inset_0_1px_6px_1px_#000000]',
                {
                  ['opacity-60']: !isExpired && !character.online,
                  ['opacity-100']: !isExpired && character.online,
                  ['opacity-50']: isExpired,
                },
                '!border-0',
              )}
            />
          </WdCharStateWrapper>
        </WdTooltipWrapper>
      </li>
    );
  });

  return (
    <ul className="flex gap-1 characters" id="characters" ref={parent}>
      {items}
    </ul>
  );
};
