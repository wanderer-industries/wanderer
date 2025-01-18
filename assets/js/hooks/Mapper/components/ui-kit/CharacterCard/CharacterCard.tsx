import { useCallback } from 'react';
import clsx from 'clsx';
import classes from './CharacterCard.module.scss';
import { SystemView } from '@/hooks/Mapper/components/ui-kit/SystemView';
import { CharacterTypeRaw, WithIsOwnCharacter } from '@/hooks/Mapper/types';
import { Commands } from '@/hooks/Mapper/types/mapHandlers.ts';
import { emitMapEvent } from '@/hooks/Mapper/events';

type CharacterCardProps = {
  compact?: boolean;
  showSystem?: boolean;
  showShipName?: boolean;
  useSystemsCache?: boolean;
} & CharacterTypeRaw &
  WithIsOwnCharacter;

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

export const CharacterCard = ({
  compact,
  isOwn,
  showSystem,
  showShipName,
  useSystemsCache,
  ...char
}: CharacterCardProps) => {
  const handleSelect = useCallback(() => {
    emitMapEvent({
      name: Commands.centerSystem,
      data: char?.location?.solar_system_id?.toString(),
    });
  }, [char]);

  return (
    <div className={clsx(classes.CharacterCard, 'w-full text-xs flex flex-col box-border')} onClick={handleSelect}>
      <div className="flex px-2 py-1 w-full gap-1 overflow-hidden" style={{ minWidth: 0 }}>
        {!compact && (
          <span
            className={clsx(classes.EveIcon, classes.CharIcon, 'wd-bg-default')}
            style={{ backgroundImage: `url(https://images.evetech.net/characters/${char.eve_id}/portrait)` }}
          />
        )}
        {compact ? (
          <div
            className="grid w-full overflow-hidden items-center"
            style={{
              gridTemplateColumns: 'auto 1fr auto',
              whiteSpace: 'nowrap',
              minWidth: 0,
            }}
          >
            <div
              className="overflow-hidden text-ellipsis px-1 text-left flex-shrink-0"
              style={{ maxWidth: '1200px' }}
              title={`${char.name} [${char.alliance_id ? char.alliance_ticker : char.corporation_ticker}]`}
            >
              {char.name} [{char.alliance_id ? char.alliance_ticker : char.corporation_ticker}]
            </div>
            {showShipName && char.ship?.ship_name && (
              <div
                className="overflow-hidden text-ellipsis text-center px-1"
                style={{
                  minWidth: 0,
                }}
                title={getShipName(char.ship.ship_name)}
              >
                {getShipName(char.ship.ship_name)}
              </div>
            )}
            {char.ship?.ship_type_info?.name && (
              <div
                className="overflow-hidden text-ellipsis px-1 text-right text-yellow-400 flex-shrink-0"
                style={{ maxWidth: '120px' }}
                title={char.ship.ship_type_info.name}
              >
                {char.ship.ship_type_info.name}
              </div>
            )}
          </div>
        ) : (
          <div className="flex flex-col flex-grow overflow-hidden text-ellipsis">
            <div
              className={clsx(classes.CharRow, 'w-full', {
                [classes.TwoColumns]: !char.ship,
                [classes.ThreeColumns]: char.ship,
              })}
            >
              <span
                className={clsx(classes.CharName, 'text-ellipsis overflow-hidden whitespace-nowrap', {
                  [classes.CardBorderLeftIsOwn]: isOwn,
                })}
                title={char.name}
              >
                {char.name}
              </span>

              {char.alliance_id && <span className="text-gray-400">[{char.alliance_ticker}]</span>}
              {!char.alliance_id && <span className="text-gray-400">[{char.corporation_ticker}]</span>}

              {char.ship?.ship_type_info && (
                <div
                  className="flex-grow text-ellipsis overflow-hidden whitespace-nowrap text-yellow-400"
                  title={char.ship.ship_type_info.name}
                >
                  {char.ship.ship_type_info.name}
                </div>
              )}
            </div>
            {char.ship?.ship_name && (
              <div className="grid w-full">
                <span className="text-ellipsis overflow-hidden whitespace-nowrap">
                  {getShipName(char.ship.ship_name)}
                </span>
              </div>
            )}
            {showSystem && char.location?.solar_system_id && (
              <SystemView systemId={char.location.solar_system_id.toString()} useSystemsCache={useSystemsCache} />
            )}
          </div>
        )}
      </div>
    </div>
  );
};
