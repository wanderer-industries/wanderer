import { CharacterTypeRaw, ShipTypeRaw } from '@/hooks/Mapper/types/character.ts';

export type PassageLimitedCharacterType = Pick<
  CharacterTypeRaw,
  'alliance_ticker' | 'corporation_ticker' | 'eve_id' | 'name'
>;

export type Passage = {
  from: boolean;
  inserted_at: string; // Date
  ship: ShipTypeRaw;
  character: PassageLimitedCharacterType;
};

export type PassageWithSourceTarget = {
  source: string;
  target: string;
} & Passage;

export type ConnectionInfoOutput = {
  marl_eol_time: string;
};

export type ConnectionOutput = {
  passages: Passage[];
};
