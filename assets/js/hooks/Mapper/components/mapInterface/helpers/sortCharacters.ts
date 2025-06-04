import { CharacterTypeRaw, WithIsOwnCharacter } from '@/hooks/Mapper/types';

export const sortCharacters = (a: CharacterTypeRaw & WithIsOwnCharacter, b: CharacterTypeRaw & WithIsOwnCharacter) => {
  if (a.online === b.online) {
    return a.name.localeCompare(b.name);
  }

  if (a.online !== b.online) {
    return a.online && !b.online ? -1 : 1;
  }

  if (!a.online && !b.online) {
    return a.name.localeCompare(b.name);
  }

  if (!a.isOwn && !b.isOwn) {
    return 0;
  }
  if (a.isOwn && !b.isOwn) {
    return -1;
  }
  if (!a.isOwn && b.isOwn) {
    return 1;
  }

  return a.name.localeCompare(b.name);
};
