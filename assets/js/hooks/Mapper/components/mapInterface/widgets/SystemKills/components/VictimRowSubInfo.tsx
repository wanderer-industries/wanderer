// VictimSubRowInfo.tsx
import React from 'react';
import clsx from 'clsx';
import { zkillLink } from '../helpers';
import classes from './SystemKillRow.module.scss';

interface VictimRowSubInfoProps {
  victimCharacterId: number | null;
  victimPortraitUrl: string | null;
  victimCharName?: string;
}

export const VictimRowSubInfo: React.FC<VictimRowSubInfoProps> = ({
  victimCharacterId = 0,
  victimPortraitUrl,
  victimCharName,
}) => {
  if (!victimPortraitUrl || victimCharacterId === null || victimCharacterId <= 0) {
    return null;
  }

  return (
    <div className="flex items-start gap-1 h-14">
      <div className="relative shrink-0 w-14 h-14 overflow-hidden">
        <a
          href={zkillLink('character', victimCharacterId)}
          target="_blank"
          rel="noopener noreferrer"
          className="block w-full h-full"
        >
          <img
            src={victimPortraitUrl}
            alt={victimCharName || 'Victim Portrait'}
            className={clsx(classes.killRowImage, 'w-full h-full object-contain')}
          />
        </a>
      </div>
    </div>
  );
};
