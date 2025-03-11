import { ExtendedSystemSignature } from '../helpers/contentHelpers';

export interface UseSystemSignaturesDataProps {
  systemId: string;
  settings: { key: string; value: boolean | number }[];
  hideLinkedSignatures?: boolean;
  onCountChange?: (count: number) => void;
  onPendingChange?: (pending: ExtendedSystemSignature[], undo: () => void) => void;
  onLazyDeleteChange?: (value: boolean) => void;
  deletionTiming?: number;
}

export interface UseFetchingParams {
  systemId: string;
  signaturesRef: React.MutableRefObject<ExtendedSystemSignature[]>;
  setSignatures: React.Dispatch<React.SetStateAction<ExtendedSystemSignature[]>>;
  localPendingDeletions: ExtendedSystemSignature[];
}

export interface UsePendingDeletionParams {
  systemId: string;
  setSignatures: React.Dispatch<React.SetStateAction<ExtendedSystemSignature[]>>;
  deletionTiming?: number;
}

export interface UsePendingAdditionParams {
  setSignatures: React.Dispatch<React.SetStateAction<ExtendedSystemSignature[]>>;
  deletionTiming?: number;
}
