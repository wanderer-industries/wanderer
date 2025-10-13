import { SignatureSettingsType } from '@/hooks/Mapper/constants/signatures.ts';
import { ExtendedSystemSignature } from '@/hooks/Mapper/types';

export interface UseSystemSignaturesDataProps {
  systemId: string;
  settings: SignatureSettingsType;
  hideLinkedSignatures?: boolean;
  onCountChange?: (count: number) => void;
  onLazyDeleteChange?: (value: boolean) => void;
  deletionTiming?: number;
}

export interface UseFetchingParams {
  systemId: string;
  settings: SignatureSettingsType;
  signaturesRef: React.MutableRefObject<ExtendedSystemSignature[]>;
  setSignatures: React.Dispatch<React.SetStateAction<ExtendedSystemSignature[]>>;
}

export interface UsePendingDeletionParams {
  systemId: string;
  deletionTiming?: number;
  setSignatures: React.Dispatch<React.SetStateAction<ExtendedSystemSignature[]>>;
  onPendingChange?: (
    pending: React.MutableRefObject<Record<string, ExtendedSystemSignature>>,
    undo: () => void,
  ) => void;
}

export interface UsePendingAdditionParams {
  systemId: string;
  setSignatures: React.Dispatch<React.SetStateAction<ExtendedSystemSignature[]>>;
  deletionTiming?: number;
}
