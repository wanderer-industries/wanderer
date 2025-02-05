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
    .replace(/\\u([\dA-Fa-f]{4})/g, (_, grp) =>
      String.fromCharCode(parseInt(grp, 16))
    )
    .replace(/\\x([\dA-Fa-f]{2})/g, (_, grp) =>
      String.fromCharCode(parseInt(grp, 16))
    );
};

// A small divider between fields
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

  const shipNameText = char.ship?.ship_name ? getShipName(char.ship.ship_name) : '';
  const tickerText = char.alliance_id ? char.alliance_ticker : char.corporation_ticker;
  const shipType = char.ship?.ship_type_info?.name;

  if (compact) {
    // COMPACT MODE: one line - name, divider, then either ship name (if enabled) or ticker.
    return (
      <div
        className={clsx(classes.CharacterCard, 'w-full text-xs box-border')}
        onClick={handleSelect}
      >
        <div className="w-full px-2 py-1 flex items-center gap-2" style={{ minWidth: 0 }}>
          <img
            src={`https://images.evetech.net/characters/${char.eve_id}/portrait`}
            alt={`${char.name} portrait`}
            style={{
              width: '18px',
              height: '18px',
              borderRadius: 0,
              flexShrink: 0,
              border: '1px solid #2b2b2b',
            }}
          />
          <div className="flex flex-grow overflow-hidden text-left" style={{ minWidth: 0 }}>
            <div className="overflow-hidden text-ellipsis whitespace-nowrap">
              <span className="text-gray-200">{char.name}</span>
              <Divider />
              {showShipName && shipNameText ? (
                <span className="text-indigo-300">{shipNameText}</span>
              ) : (
                <span className="text-indigo-300">[{tickerText}]</span>
              )}
            </div>
          </div>
          {shipType && (
            <div
              className="text-yellow-400 overflow-hidden text-ellipsis whitespace-nowrap flex-shrink-0"
              style={{ maxWidth: '120px' }}
              title={shipType}
            >
              {shipType}
            </div>
          )}
        </div>
      </div>
    );
  } else {
    // FULL MODE:
    // Determine if a location is being shown
    const locationShown = showSystem && char.location?.solar_system_id;

    return (
      <div
        className={clsx(classes.CharacterCard, 'w-full text-xs box-border')}
        onClick={handleSelect}
      >
        <div className="w-full px-2 py-1 flex items-center gap-2" style={{ minWidth: 0 }}>
          <span
            className={clsx(classes.EveIcon, classes.CharIcon, 'wd-bg-default')}
            style={{
              backgroundImage: `url(https://images.evetech.net/characters/${char.eve_id}/portrait)`,
              minWidth: '33px',
              minHeight: '33px',
              width: '33px',
              height: '33px',
            }}
          />
          {/* Left column */}
          <div className="flex flex-col flex-grow overflow-hidden" style={{ minWidth: 0 }}>
            {/* First line: Character name and ticker */}
            <div className="overflow-hidden text-ellipsis whitespace-nowrap">
              <span className="text-gray-200">{char.name}</span>
              <Divider />
              <span className="text-indigo-300">[{tickerText}]</span>
            </div>
            {locationShown ? (
              // If location is shown, render the system view in the left column.
              <div className="text-gray-300 text-xs overflow-hidden text-ellipsis whitespace-nowrap">
                <SystemView
                  systemId={char.location.solar_system_id.toString()}
                  useSystemsCache={useSystemsCache}
                />
              </div>
            ) : (
              // Otherwise, render the ship name (if available) in the left column.
              shipNameText && (
                <div className="text-gray-300 text-xs overflow-hidden text-ellipsis whitespace-nowrap">
                  {shipNameText}
                </div>
              )
            )}
          </div>
          {/* Right column */}
          {((shipType) || (locationShown && shipNameText)) && (
            <div className="flex-shrink-0 self-start">
              {shipType && (
                <div
                  className="text-yellow-400 overflow-hidden text-ellipsis whitespace-nowrap"
                  style={{ maxWidth: '200px' }}
                  title={shipType}
                >
                  {shipType}
                </div>
              )}
              {locationShown && shipNameText && (
                <div
                  className="text-gray-300 text-xs overflow-hidden text-ellipsis whitespace-nowrap text-right"
                  style={{ maxWidth: '200px' }}
                >
                  {shipNameText}
                </div>
              )}
            </div>
          )}
        </div>
      </div>
    );
  }
};
