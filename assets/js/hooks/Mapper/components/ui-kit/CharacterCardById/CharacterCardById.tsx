import { CharacterCard, CharacterCardProps } from '@/hooks/Mapper/components/ui-kit/CharacterCard';
import { useMapRootState } from '@/hooks/Mapper/mapRootProvider';
import { useMemo } from 'react';

type CharacterCardByIdProps = {
  characterId: string;
} & Omit<CharacterCardProps, 'isOwn'>;

export const CharacterCardById = ({ characterId, ...props }: CharacterCardByIdProps) => {
  const {
    data: { characters },
  } = useMapRootState();

  const charInfo = useMemo(() => {
    return characters.find(x => x.eve_id === characterId);
  }, [characterId, characters]);

  if (!charInfo) {
    return 'No character found.';
  }

  return <CharacterCard isOwn={false} {...charInfo} {...props} />;
};
