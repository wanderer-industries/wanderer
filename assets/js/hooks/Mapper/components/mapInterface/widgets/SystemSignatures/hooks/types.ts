// types.ts
import { ExtendedSystemSignature } from '../helpers/contentHelpers';
import { OutCommandHandler } from '@/hooks/Mapper/types/mapHandlers'; // or your function type

/**
 * The aggregator’s props
 */
export interface UseSystemSignaturesDataProps {
  systemId: string;
  settings: { key: string; value: boolean }[];
  hideLinkedSignatures?: boolean;
  onCountChange?: (count: number) => void;
  onPendingChange?: (pending: ExtendedSystemSignature[], undo: () => void) => void;
  onLazyDeleteChange?: (value: boolean) => void;
}

/**
 * The minimal fetch logic
 */
export interface UseFetchingParams {
  systemId: string;
  signaturesRef: React.MutableRefObject<ExtendedSystemSignature[]>;
  setSignatures: React.Dispatch<React.SetStateAction<ExtendedSystemSignature[]>>;
  localPendingDeletions: ExtendedSystemSignature[];
}

/**
 * For the deletion sub-hook
 */
export interface UsePendingDeletionParams {
  systemId: string;
  setSignatures: React.Dispatch<React.SetStateAction<ExtendedSystemSignature[]>>;
}

/**
 * For the additions sub-hook
 */
export interface UsePendingAdditionParams {
  setSignatures: React.Dispatch<React.SetStateAction<ExtendedSystemSignature[]>>;
}
