/**
 * Interface for a character that can be tracked and followed
 */
export interface TrackingCharacter {
  id: string;
  name: string;
  corporation_ticker: string;
  alliance_ticker?: string;
  portrait_url: string;
  tracked: boolean;
  followed: boolean;
}
