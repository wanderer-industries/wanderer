export type EffectModifierRaw = {
  name: string;
  positive: boolean;
  power: string[];
};

export type EffectRaw = {
  id: string;
  name: string;
  modifiers: EffectModifierRaw[];
};
