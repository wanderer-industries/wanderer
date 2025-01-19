import { useCallback } from 'react';
import clsx from 'clsx';
import classes from './CharacterCard.module.scss';
import { SystemView } from '@/hooks/Mapper/components/ui-kit/SystemView';
import { CharacterTypeRaw, WithIsOwnCharacter } from '@/hooks/Mapper/types';
import { Commands } from '@/hooks/Mapper/types/mapHandlers';
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

// A small divider between fields:
const Divider = () => (
  <span className="mx-1 text-gray-400" aria-hidden="true">
    |
  </span>
);

export const CharacterCard = ({
  compact = false,
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

  // Precompute the ship name (decoded):
  const shipNameText = char.ship?.ship_name ? getShipName(char.ship.ship_name) : '';

  // -----------------------------------------------------------------------------
  // COMPACT MODE: Main line =
  //   if (showShipName & haveShipName) => name | shipName (skip ticker)
  //   else => name | [ticker]
  // -----------------------------------------------------------------------------
  const compactLine = (
    <>
      {/* Character Name (lighter shade) */}
      <span className="text-gray-200">{char.name}</span>
      <Divider />
      {showShipName && shipNameText ? (
        // Show the ship name in place of the ticker (lighter shade)
        <span className="text-gray-300">{shipNameText}</span>
      ) : (
        // Show the [ticker] (indigo)
        <span className="text-indigo-300">[{char.alliance_id ? char.alliance_ticker : char.corporation_ticker}]</span>
      )}
    </>
  );

  // -----------------------------------------------------------------------------
  // NON-COMPACT MODE:
  //   Line 1 => name | [ticker]
  //   Line 2 => (shipName) always, if it exists
  // -----------------------------------------------------------------------------
  const nonCompactLine1 = (
    <div className="overflow-hidden text-ellipsis whitespace-nowrap">
      {/* Character Name (lighter shade) */}
      <span className="text-gray-200">{char.name}</span>
      <Divider />
      <span className="text-indigo-300">[{char.alliance_id ? char.alliance_ticker : char.corporation_ticker}]</span>
    </div>
  );

  const nonCompactLine2 = (
    <>
      {shipNameText && (
        <div className="overflow-hidden text-ellipsis whitespace-nowrap text-gray-300">{shipNameText}</div>
      )}
    </>
  );

  return (
    <div className={clsx(classes.CharacterCard, 'w-full text-xs box-border')} onClick={handleSelect}>
      {/*
        Layout container - conditionally grid (compact) vs. flex (non-compact).
        In compact mode, we display 3 columns: [Portrait | (name/ticker line) | ShipType].
        In non-compact mode, it becomes a vertical block (flex-col) or row (flex-row) with lines.
      */}
      <div
        className={clsx(
          'w-full px-2 py-1 overflow-hidden gap-1',
          compact ? 'grid items-center' : 'flex flex-col md:flex-row items-start',
        )}
        style={compact ? { gridTemplateColumns: 'auto 1fr auto', minWidth: 0 } : undefined}
      >
        {/*
          Left column: portrait (different render for compact vs. non-compact)
        */}
        {compact ? (
          <img
            src={`https://images.evetech.net/characters/${char.eve_id}/portrait`}
            alt={`${char.name} portrait`}
            style={{
              width: '18px',
              height: '18px',
              borderRadius: '50%',
              marginRight: '4px',
              flexShrink: 0,
            }}
          />
        ) : (
          <span
            className={clsx(classes.EveIcon, classes.CharIcon, 'wd-bg-default')}
            style={{
              backgroundImage: `url(https://images.evetech.net/characters/${char.eve_id}/portrait)`,
            }}
          />
        )}

        {/*
          Middle section:
          - In compact mode, everything is on one line (Name + possibly ShipName or ticker).
          - In non-compact mode, line 1 has (Name | Ticker), line 2 has shipName if it exists.
        */}
        <div
          className={clsx('overflow-hidden text-ellipsis', {
            'text-left px-1': compact,
            'flex-grow': !compact,
          })}
          style={{ minWidth: 0 }}
        >
          {/* This left border highlights "isOwn" in the same way as older code. */}
          <div
            className={clsx('overflow-hidden whitespace-nowrap', {
              [classes.CardBorderLeftIsOwn]: isOwn,
            })}
          >
            {compact ? compactLine : nonCompactLine1}
          </div>
          {/* Non-compact second line always shows shipName if available */}
          {!compact && nonCompactLine2}
        </div>

        {/*
          Right column for Ship Type (compact) or "pushed" to the right (non-compact).
          Ship Type remains text-yellow-400.
        */}
        {char.ship?.ship_type_info?.name && (
          <div
            className={clsx('text-yellow-400 text-ellipsis overflow-hidden whitespace-nowrap', {
              'text-right px-1 flex-shrink-0': compact,
              'mt-1 md:mt-0 ml-auto': !compact,
            })}
            style={{ maxWidth: compact ? '120px' : '200px' }}
            title={char.ship.ship_type_info.name}
          >
            {char.ship.ship_type_info.name}
          </div>
        )}
      </div>

      {/*
        System row at the bottom if `showSystem && system exists`.
      */}
      {showSystem && char.location?.solar_system_id && (
        <div className="px-2 pb-1">
          <SystemView systemId={char.location.solar_system_id.toString()} useSystemsCache={useSystemsCache} />
        </div>
      )}
    </div>
  );
};
