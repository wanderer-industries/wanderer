import { CharacterTypeRaw } from '@/hooks/Mapper/types';
/**
 * Interface for a character that can be tracked and followed
 */
export interface TrackingCharacter {
  character: CharacterTypeRaw;
  tracked: boolean;
  followed: boolean;
}
