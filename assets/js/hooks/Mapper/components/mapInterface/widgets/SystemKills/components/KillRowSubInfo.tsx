import React from 'react';
import clsx from 'clsx';
import { zkillLink } from '../helpers';
import classes from './SystemKillRow.module.scss';

interface KillRowSubInfoProps {
  victimCorpId: number | null | undefined;
  victimCorpLogoUrl: string | null;
  victimAllianceId: number | null | undefined;
  victimAllianceLogoUrl: string | null;
  victimCharacterId: number | null | undefined;
  victimPortraitUrl: string | null;
}

export const KillRowSubInfo: React.FC<KillRowSubInfoProps> = ({
  victimCorpId,
  victimCorpLogoUrl,
  victimAllianceId,
  victimAllianceLogoUrl,
  victimCharacterId,
  victimPortraitUrl,
}) => {
  const hasAnything = victimPortraitUrl || victimCorpLogoUrl || victimAllianceLogoUrl;

  if (!hasAnything) {
    return null;
  }

  return (
    <div className="flex items-start gap-1 h-full">
      {victimPortraitUrl && victimCharacterId && (
        <a
          href={zkillLink('character', victimCharacterId)}
          target="_blank"
          rel="noopener noreferrer"
          className="shrink-0 h-full"
        >
          <img
            src={victimPortraitUrl}
            alt="VictimPortrait"
            className={clsx(classes.killRowImage, 'h-full w-auto object-contain')}
          />
        </a>
      )}
      <div className="flex flex-col h-full justify-between">
        {victimCorpLogoUrl && victimCorpId && (
          <a
            href={zkillLink('corporation', victimCorpId)}
            target="_blank"
            rel="noopener noreferrer"
            className="shrink-0 h-[26px]"
          >
            <img
              src={victimCorpLogoUrl}
              alt="VictimCorp"
              className={clsx(classes.killRowImage, 'w-auto h-full object-contain')}
            />
          </a>
        )}
        {victimAllianceLogoUrl && victimAllianceId && (
          <a
            href={zkillLink('alliance', victimAllianceId)}
            target="_blank"
            rel="noopener noreferrer"
            className="shrink-0 h-[26px]"
          >
            <img
              src={victimAllianceLogoUrl}
              alt="VictimAlliance"
              className={clsx(classes.killRowImage, 'w-auto h-full object-contain')}
            />
          </a>
        )}
      </div>
    </div>
  );
};
