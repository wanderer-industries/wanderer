export enum Respawn {
  static = 'static',
  wandering = 'wandering',
  reverse = 'reverse',
}

export type WormholeDataRaw = {
  dest: string;
  id: number;
  lifetime: string;
  mass_regen: number;
  max_mass_per_jump: number;
  name: string;
  respawn: Respawn[];
  src: string[];
  static: boolean;
  total_mass: number;
};
