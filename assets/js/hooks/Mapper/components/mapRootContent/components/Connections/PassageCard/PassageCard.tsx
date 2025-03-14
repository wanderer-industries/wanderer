import clsx from 'clsx';
import classes from './PassageCard.module.scss';
import { Passage } from '@/hooks/Mapper/types';
import { TimeAgo } from '@/hooks/Mapper/components/ui-kit';
import { WdTooltipWrapper } from '@/hooks/Mapper/components/ui-kit/WdTooltipWrapper';
import { kgToTons } from '@/hooks/Mapper/utils/kgToTons.ts';
import { useMemo } from 'react';

type PassageCardType = {
  // compact?: boolean;
  showShipName?: boolean;
  // showSystem?: boolean;
  // useSystemsCache?: boolean;
} & Passage;

const SHIP_NAME_RX = /u'|'/g;
export const getShipName = (name: string) => {
  return name
    .replace(SHIP_NAME_RX, '')
    .replace(/\\u([\dA-Fa-f]{4})/g, (_, grp) => {
      return String.fromCharCode(parseInt(grp, 16));
    })
    .replace(/\\x([\dA-Fa-f]{2})/g, (_, grp) => {
      return String.fromCharCode(parseInt(grp, 16));
    });
};

export const PassageCard = ({ inserted_at, character: char, ship }: PassageCardType) => {
  const isOwn = false;

  const insertedAt = useMemo(() => {
    const date = new Date(inserted_at);
    return date.toLocaleString();
  }, [inserted_at]);

  return (
    <div className={clsx(classes.CharacterCard, 'w-full text-xs', 'flex flex-col box-border')}>
      <div className="flex flex-col justify-between px-2 py-1 gap-1">
        {/*here icon and other*/}
        <div className={clsx(classes.CharRow, classes.ThreeColumns)}>
          {/*portrait*/}
          <span
            className={clsx(classes.EveIcon, classes.CharIcon, 'wd-bg-default')}
            style={{ backgroundImage: `url(https://images.evetech.net/characters/${char.eve_id}/portrait)` }}
          />

          {/*info*/}
          <div className="flex flex-col">
            {/*here name and ship name*/}
            <div className="grid gap-1 justify-between grid-cols-[max-content_1fr]">
              {/*char name*/}
              <div className="grid gap-1 grid-cols-[auto_1px_1fr]">
                <span
                  className={clsx(classes.MaxWidth, 'text-ellipsis overflow-hidden whitespace-nowrap', {
                    [classes.CardBorderLeftIsOwn]: isOwn,
                  })}
                  title={char.name}
                >
                  {char.name}
                </span>

                <div className="h-3 border-r border-neutral-500 my-0.5"></div>
                {char.alliance_ticker && <span className="text-neutral-400">{char.alliance_ticker}</span>}
                {!char.alliance_ticker && <span className="text-neutral-400">{char.corporation_ticker}</span>}
              </div>

              {/*ship name*/}
              <div className="grid gap-1 grid-cols-[1fr_1px_auto]">
                {ship.ship_name && (
                  <>
                    <span className="text-ellipsis overflow-hidden whitespace-nowrap flex justify-end text-neutral-400">
                      {getShipName(ship.ship_name)}
                    </span>
                    <div className="h-3 border-r border-neutral-500 my-0.5"></div>
                    <span className={clsx(classes.MaxWidth, 'text-ellipsis overflow-hidden whitespace-nowrap')}>
                      {ship.ship_type_info.name}
                    </span>
                  </>
                )}
              </div>
            </div>

            {/*time and class*/}
            <div className="flex justify-between">
              <span className="text-stone-400">
                <WdTooltipWrapper content={insertedAt}>
                  <TimeAgo timestamp={inserted_at} />
                </WdTooltipWrapper>
              </span>

              <div className="text-stone-400">{kgToTons(parseInt(ship.ship_type_info.mass))}</div>
            </div>
          </div>

          {/*ship icon*/}
          <span
            className={clsx(classes.EveIcon, classes.CharIcon, 'wd-bg-default')}
            style={{ backgroundImage: `url(https://images.evetech.net/types/${ship.ship_type_id}/icon)` }}
          />
        </div>
      </div>
    </div>
  );
};
