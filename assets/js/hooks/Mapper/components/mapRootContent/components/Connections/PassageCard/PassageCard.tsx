import clsx from 'clsx';
import classes from './PassageCard.module.scss';
import { PassageWithSourceTarget } from '@/hooks/Mapper/types';
import { SystemView, TimeAgo, TooltipPosition, WdImgButton } from '@/hooks/Mapper/components/ui-kit';
import { WdTooltipWrapper } from '@/hooks/Mapper/components/ui-kit/WdTooltipWrapper';
import { kgToTons } from '@/hooks/Mapper/utils/kgToTons.ts';
import { useCallback, useMemo } from 'react';
import { ZKB_ICON } from '@/hooks/Mapper/icons';
import { charEveWhoLink, charZKBLink } from '@/hooks/Mapper/helpers/linkHelpers.ts';

type PassageCardType = {
  // compact?: boolean;
  showShipName?: boolean;
  // showSystem?: boolean;
  // useSystemsCache?: boolean;
} & PassageWithSourceTarget;

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

export const PassageCard = ({ inserted_at, character: char, ship, source, target, from }: PassageCardType) => {
  const isOwn = false;

  const insertedAt = useMemo(() => {
    const date = new Date(inserted_at);
    return date.toLocaleString();
  }, [inserted_at]);

  const handleOpenZKB = useCallback(() => window.open(charZKBLink(char.eve_id), '_blank'), [char]);
  const handleOpenEveWho = useCallback(() => window.open(charEveWhoLink(char.eve_id), '_blank'), [char]);

  return (
    <div className={clsx(classes.CharacterCard, 'w-full text-xs', 'flex flex-col box-border')}>
      <div className="flex flex-col justify-between px-2 py-1 gap-1">
        {/*here icon and other*/}
        <div className={clsx(classes.CharRow, classes.FourColumns)}>
          <WdTooltipWrapper
            position={TooltipPosition.top}
            content={
              <div className="flex justify-between gap-2 items-center">
                <SystemView
                  showCustomName
                  systemId={source}
                  className="select-none text-center !text-[12px]"
                  hideRegion
                />
                <span className="pi pi-angle-double-right text-stone-500 text-[15px]"></span>
                <SystemView
                  showCustomName
                  systemId={target}
                  className="select-none text-center !text-[12px]"
                  hideRegion
                />
              </div>
            }
          >
            <div
              className={clsx(
                'transition-all transform ease-in duration-200',
                'pi text-stone-500 text-[15px] w-[35px] h-[33px] !flex items-center justify-center border rounded-[6px]',
                {
                  ['pi-angle-double-right !text-orange-400 border-orange-400 hover:bg-orange-400/30']: from,
                  ['pi-angle-double-left !text-stone-500/70 border-stone-500/70 hover:bg-stone-500/30']: !from,
                },
              )}
            />
          </WdTooltipWrapper>

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
              <div className="grid gap-1 grid-cols-[auto_1px_1fr_auto]">
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

                <div className={clsx('flex gap-1 items-center h-full ml-[2px]')}>
                  <WdImgButton
                    width={16}
                    height={16}
                    tooltip={{ position: TooltipPosition.top, content: 'Open zkillboard' }}
                    source={ZKB_ICON}
                    onClick={handleOpenZKB}
                  />
                  <WdImgButton
                    tooltip={{ position: TooltipPosition.top, content: 'Open Eve Who' }}
                    className={clsx('pi pi-user', '!text-[12px] relative top-[-1px]')}
                    onClick={handleOpenEveWho}
                  />
                </div>
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
