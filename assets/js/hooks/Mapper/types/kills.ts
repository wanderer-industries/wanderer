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
  victim_char_name?: string;
  victim_corp_id?: number | null;
  victim_corp_ticker?: string;
  victim_corp_name?: string;
  victim_alliance_id?: number | null;
  victim_alliance_ticker?: string;
  victim_alliance_name?: string;
  victim_ship_type_id?: number | null;
  victim_ship_name?: string;

  final_blow_char_id?: number | null;
  final_blow_char_name?: string;
  final_blow_corp_id?: number | null;
  final_blow_corp_ticker?: string;
  final_blow_corp_name?: string;
  final_blow_alliance_id?: number | null;
  final_blow_alliance_ticker?: string;
  final_blow_alliance_name?: string;
  final_blow_ship_type_id?: number | null;
  final_blow_ship_name?: string;

  attacker_count?: number | null;
  total_value?: number | null;
  npc?: boolean;
}
