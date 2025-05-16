export enum PingType {
  Alert,
  Rally,
}

export type PingData = {
  inserted_at: number;
  character_eve_id: string;
  solar_system_id: string;
  message: string;
  type: PingType;
};
