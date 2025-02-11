import React from 'react';
import { DetailedKill } from '@/hooks/Mapper/types/kills';
import { CompactKillRow } from './CompactKillRow';
import { FullKillRow } from './FullKillRow';

export interface KillRowProps {
  killDetails: DetailedKill;
  systemName: string;
  isCompact?: boolean;
  onlyOneSystem?: boolean;
}

const KillRowComponent: React.FC<KillRowProps> = ({
  killDetails,
  systemName,
  isCompact = false,
  onlyOneSystem = false,
}) => {
  if (isCompact) {
    return <CompactKillRow killDetails={killDetails} systemName={systemName} onlyOneSystem={onlyOneSystem} />;
  }
  return <FullKillRow killDetails={killDetails} systemName={systemName} onlyOneSystem={onlyOneSystem} />;
};

export const KillRow = React.memo(KillRowComponent);
