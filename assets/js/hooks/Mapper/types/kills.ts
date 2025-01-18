export type Kill = {
  solar_system_id: number;
  kills: number;
};

export interface DetailedKill {
  killmail_id: number;
  solar_system_id: number;
  kill_time?: string;

  zkb?: Record<string, unknown>;

  victim_char_id?: number | null;
  victim_corp_id?: number | null;
  victim_alliance_id?: number | null;
  victim_ship_type_id?: number | null;
  total_value?: number | null;

  final_blow_char_id?: number | null;
  final_blow_corp_id?: number | null;
  final_blow_alliance_id?: number | null;
  final_blow_ship_type_id?: number | null;
  attacker_count?: number | null;

  npc?: boolean | false;
}
