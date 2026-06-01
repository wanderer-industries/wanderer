import { CharacterTypeRaw, ShipTypeRaw } from '@/hooks/Mapper/types/character.ts';

export type PassageLimitedCharacterType = Pick<
  CharacterTypeRaw,
  'alliance_ticker' | 'corporation_ticker' | 'eve_id' | 'name'
>;

export type Passage = {
  id: string;
  from: boolean;
  inserted_at: string; // Date
  mass: number | null;
  ship: ShipTypeRaw;
  character: PassageLimitedCharacterType;
};

export type PassageWithSourceTarget = {
  source: string;
  target: string;
} & Passage;

export type ConnectionInfoOutput = {
  marl_eol_time: string;
  locked_at: string | null;
  locked_by_name: string | null;
};

export type ConnectionOutput = {
  passages: Passage[];
};
