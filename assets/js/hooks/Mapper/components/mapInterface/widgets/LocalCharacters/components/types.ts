import { CharacterTypeRaw, WithIsOwnCharacter } from '@/hooks/Mapper/types';

export type CharItemProps = {
  compact: boolean;
} & CharacterTypeRaw &
  WithIsOwnCharacter;
