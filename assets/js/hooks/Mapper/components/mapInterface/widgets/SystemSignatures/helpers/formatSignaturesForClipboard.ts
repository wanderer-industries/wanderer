import { UNKNOWN_SIGNATURE_NAME } from '@/hooks/Mapper/helpers';
import { SignatureGroup, SystemSignature } from '@/hooks/Mapper/types';

const EMPTY_SCAN_VALUE = '';
const DEFAULT_SIGNAL_STRENGTH = '0,0%';
const DEFAULT_DISTANCE = '0 m';

const formatSignatureRow = (signature: SystemSignature): string => {
  const hasResolvedGroup = Boolean(signature.group) && signature.group !== SignatureGroup.CosmicSignature;
  const hasResolvedName = hasResolvedGroup && Boolean(signature.name) && signature.name !== UNKNOWN_SIGNATURE_NAME;
  const group = hasResolvedGroup ? signature.group : EMPTY_SCAN_VALUE;
  const name = hasResolvedName ? signature.name : EMPTY_SCAN_VALUE;

  return [signature.eve_id, signature.kind, group, name, DEFAULT_SIGNAL_STRENGTH, DEFAULT_DISTANCE].join('\t');
};

export const formatSignaturesForClipboard = (signatures: SystemSignature[]): string =>
  signatures.map(formatSignatureRow).join('\n');
