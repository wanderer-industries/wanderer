import React from 'react';
import clsx from 'clsx';
import { zkillLink } from '../helpers';
import classes from './SystemKillRow.module.scss';

interface AttackerRowSubInfoProps {
  finalBlowCharId: number | null | undefined;
  finalBlowCharName?: string;
  attackerPortraitUrl: string | null;

  finalBlowCorpId: number | null | undefined;
  finalBlowCorpName?: string;
  attackerCorpLogoUrl: string | null;

  finalBlowAllianceId: number | null | undefined;
  finalBlowAllianceName?: string;
  attackerAllianceLogoUrl: string | null;

  containerHeight?: number;
}

export const AttackerRowSubInfo: React.FC<AttackerRowSubInfoProps> = ({
  finalBlowCharId = 0,
  finalBlowCharName,
  attackerPortraitUrl,
  containerHeight = 8,
}) => {
  if (!attackerPortraitUrl || finalBlowCharId === null || finalBlowCharId <= 0) {
    return null;
  }

  const containerClass = `h-${containerHeight}`;

  return (
    <div className={clsx('flex items-start gap-1', containerClass)}>
      <div className="relative shrink-0 w-auto h-full overflow-hidden">
        <a
          href={zkillLink('character', finalBlowCharId)}
          target="_blank"
          rel="noopener noreferrer"
          className="block h-full"
        >
          <img
            src={attackerPortraitUrl}
            alt={finalBlowCharName || 'AttackerPortrait'}
            className={clsx(classes.killRowImage, 'h-full w-auto object-contain')}
          />
        </a>
      </div>
    </div>
  );
};
