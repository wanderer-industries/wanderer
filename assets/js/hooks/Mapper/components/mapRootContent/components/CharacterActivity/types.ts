import { CharacterTypeRaw } from '@/hooks/Mapper/types';

export interface ActivitySummary {
  character: CharacterTypeRaw;
  passages: number;
  connections: number;
  signatures: number;
}
