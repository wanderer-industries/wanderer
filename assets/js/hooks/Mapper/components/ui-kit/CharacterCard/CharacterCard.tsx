import { useCallback } from 'react';
import clsx from 'clsx';
import { SystemView } from '@/hooks/Mapper/components/ui-kit/SystemView';
import { CharacterTypeRaw, WithIsOwnCharacter } from '@/hooks/Mapper/types';
import { Commands } from '@/hooks/Mapper/types/mapHandlers';
import { emitMapEvent } from '@/hooks/Mapper/events';
import {
  TooltipPosition,
  WdEveEntityPortrait,
  WdEveEntityPortraitSize,
  WdEveEntityPortraitType,
  WdTooltipWrapper,
} from '@/hooks/Mapper/components/ui-kit';
import { isDocked } from '@/hooks/Mapper/helpers/isDocked.ts';
import classes from './CharacterCard.module.scss';

type CharacterCardProps = {
  compact?: boolean;
  showSystem?: boolean;
  showTicker?: boolean;
  showShipName?: boolean;
  useSystemsCache?: boolean;
  showCorporationLogo?: boolean;
  showAllyLogo?: boolean;
} & CharacterTypeRaw &
  WithIsOwnCharacter;

const SHIP_NAME_RX = /u'|'/g;
export const getShipName = (name: string) => {
  return name
    .replace(SHIP_NAME_RX, '')
    .replace(/\\u([\dA-Fa-f]{4})/g, (_, grp) => String.fromCharCode(parseInt(grp, 16)))
    .replace(/\\x([\dA-Fa-f]{2})/g, (_, grp) => String.fromCharCode(parseInt(grp, 16)));
};

export const CharacterCard = ({
  compact = false,
  isOwn,
  showSystem,
  showShipName,
  showCorporationLogo,
  showAllyLogo,
  showTicker,
  useSystemsCache,
  ...char
}: CharacterCardProps) => {
  const handleSelect = useCallback(() => {
    emitMapEvent({
      name: Commands.centerSystem,
      data: char?.location?.solar_system_id?.toString(),
    });
  }, [char]);

  const shipNameText = char.ship?.ship_name ? getShipName(char.ship.ship_name) : '';
  const tickerText = char.alliance_id ? char.alliance_ticker : char.corporation_ticker;
  const shipType = char.ship?.ship_type_info?.name;
  const locationShown = showSystem && char.location?.solar_system_id;

  if (compact) {
    return (
      <div className="text-xs box-border w-full" onClick={handleSelect}>
        <div className="w-full flex items-center gap-1 relative">
          <WdEveEntityPortrait eveId={char.eve_id} size={WdEveEntityPortraitSize.w18} />

          {showCorporationLogo && (
            <WdTooltipWrapper position={TooltipPosition.top} content={char.corporation_name}>
              <WdEveEntityPortrait
                type={WdEveEntityPortraitType.corporation}
                eveId={char.corporation_id.toString()}
                size={WdEveEntityPortraitSize.w18}
              />
            </WdTooltipWrapper>
          )}

          {showAllyLogo && char.alliance_id && (
            <WdTooltipWrapper position={TooltipPosition.top} content={char.alliance_name}>
              <WdEveEntityPortrait
                type={WdEveEntityPortraitType.alliance}
                eveId={char.alliance_id.toString()}
                size={WdEveEntityPortraitSize.w18}
              />
            </WdTooltipWrapper>
          )}

          {isDocked(char.location) && <span className={classes.Docked} />}
          <div className="flex flex-grow-[2] overflow-hidden text-left w-[50px]">
            <div className="flex min-w-0">
              <span
                className={clsx(
                  'overflow-hidden text-ellipsis whitespace-nowrap',
                  isOwn ? 'text-orange-400' : 'text-gray-200',
                )}
                title={char.name}
              >
                {char.name}
              </span>
              {showTicker && <span className="flex-shrink-0 text-gray-400 ml-1">[{tickerText}]</span>}
            </div>
          </div>

          {shipType && (
            <>
              {!showShipName && (
                <div
                  className="text-gray-300 overflow-hidden text-ellipsis whitespace-nowrap flex-shrink-0"
                  style={{ maxWidth: '120px' }}
                  title={shipType}
                >
                  {shipType}
                </div>
              )}
              {showShipName && (
                <div className="flex flex-grow-[1] justify-end w-[50px]">
                  <div className="min-w-0">
                    <div
                      className="text-gray-300 overflow-hidden text-ellipsis whitespace-nowrap flex-shrink-0"
                      style={{ maxWidth: '120px' }}
                      title={shipNameText}
                    >
                      {shipNameText}
                    </div>
                  </div>
                </div>
              )}
              {char.ship && (
                <WdTooltipWrapper position={TooltipPosition.top} content={char.ship.ship_type_info.name}>
                  <WdEveEntityPortrait
                    type={WdEveEntityPortraitType.ship}
                    eveId={char.ship.ship_type_id.toString()}
                    size={WdEveEntityPortraitSize.w18}
                  />
                </WdTooltipWrapper>
              )}
            </>
          )}
        </div>
      </div>
    );
  }

  return (
    <div className={clsx('w-full text-xs box-border')} onClick={handleSelect}>
      <div className="w-full flex items-center gap-2">
        <div className="flex items-center gap-1">
          <WdEveEntityPortrait eveId={char.eve_id} size={WdEveEntityPortraitSize.w33} />

          {showCorporationLogo && (
            <WdTooltipWrapper position={TooltipPosition.top} content={char.corporation_name}>
              <WdEveEntityPortrait
                type={WdEveEntityPortraitType.corporation}
                eveId={char.corporation_id.toString()}
                size={WdEveEntityPortraitSize.w33}
              />
            </WdTooltipWrapper>
          )}

          {showAllyLogo && char.alliance_id && (
            <WdTooltipWrapper position={TooltipPosition.top} content={char.alliance_name}>
              <WdEveEntityPortrait
                type={WdEveEntityPortraitType.alliance}
                eveId={char.alliance_id.toString()}
                size={WdEveEntityPortraitSize.w33}
              />
            </WdTooltipWrapper>
          )}
        </div>

        <div className="flex flex-col flex-grow overflow-hidden  w-[50px]">
          <div className="flex min-w-0">
            <span
              className={clsx(
                'overflow-hidden text-ellipsis whitespace-nowrap',
                isOwn ? 'text-orange-400' : 'text-gray-200',
              )}
            >
              {char.name}
            </span>
            {showTicker && <span className="flex-shrink-0 text-gray-400 ml-1">[{tickerText}]</span>}
          </div>
          {locationShown ? (
            <div className="text-gray-300 text-xs overflow-hidden text-ellipsis whitespace-nowrap">
              <SystemView
                systemId={char?.location?.solar_system_id?.toString() || ''}
                useSystemsCache={useSystemsCache}
              />
            </div>
          ) : (
            shipNameText && (
              <div className="text-gray-300 text-xs overflow-hidden text-ellipsis whitespace-nowrap">
                {shipNameText}
              </div>
            )
          )}
        </div>
        {shipType && (
          <>
            <div className="flex flex-col flex-shrink-0 items-end self-start">
              <div
                className="text-gray-300 overflow-hidden text-ellipsis whitespace-nowrap max-w-[200px]"
                title={shipType}
              >
                {shipType}
              </div>
              <div
                className="flex justify-end text-stone-500 overflow-hidden text-ellipsis whitespace-nowrap max-w-[200px]"
                title={shipNameText}
              >
                {shipNameText}
              </div>
            </div>

            {char.ship && (
              <WdEveEntityPortrait
                type={WdEveEntityPortraitType.ship}
                eveId={char.ship.ship_type_id.toString()}
                size={WdEveEntityPortraitSize.w33}
              />
            )}
          </>
        )}
      </div>
    </div>
  );
};
