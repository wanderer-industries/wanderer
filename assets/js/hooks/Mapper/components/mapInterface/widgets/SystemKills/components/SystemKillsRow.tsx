import React from 'react';
import { DetailedKill } from '@/hooks/Mapper/types/kills';
import { KillRowDetail } from './KillRowDetail.tsx';

export interface KillRowProps {
  killDetails: DetailedKill;
  systemName: string;
  onlyOneSystem?: boolean;
}

const KillRowComponent: React.FC<KillRowProps> = ({ killDetails, systemName, onlyOneSystem = false }) => {
  return <KillRowDetail killDetails={killDetails} systemName={systemName} onlyOneSystem={onlyOneSystem} />;
};

export const KillRow = React.memo(KillRowComponent);
