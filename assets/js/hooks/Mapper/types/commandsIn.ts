import { TrackingCharacter } from './character.ts';

export type CommandInCharactersTrackingInfo = {
  characters: TrackingCharacter[];
  following: string | null;
  main: string | null;
};
