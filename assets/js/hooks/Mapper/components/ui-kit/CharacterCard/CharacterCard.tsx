import { useCallback } from 'react';
import clsx from 'clsx';
import { SystemView } from '@/hooks/Mapper/components/ui-kit/SystemView';
import { CharacterTypeRaw, WithIsOwnCharacter } from '@/hooks/Mapper/types';
import { Commands } from '@/hooks/Mapper/types/mapHandlers';
import { emitMapEvent } from '@/hooks/Mapper/events';
import { CharacterPortrait, CharacterPortraitSize } from '@/hooks/Mapper/components/ui-kit';

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
    .replace(/\\u([\dA-Fa-f]{4})/g, (_, grp) => String.fromCharCode(parseInt(grp, 16)))
    .replace(/\\x([\dA-Fa-f]{2})/g, (_, grp) => String.fromCharCode(parseInt(grp, 16)));
};

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
  const locationShown = showSystem && char.location?.solar_system_id;

  if (compact) {
    return (
      <div className={clsx('w-full text-xs box-border')} onClick={handleSelect}>
        <div className="w-full flex items-center gap-1">
          <CharacterPortrait characterEveId={char.eve_id} size={CharacterPortraitSize.w18} />
          <div className="flex flex-grow overflow-hidden text-left">
            <div className="overflow-hidden text-ellipsis whitespace-nowrap">
              <span className={clsx(isOwn ? 'text-orange-400' : 'text-gray-200')}>{char.name}</span>{' '}
              <span className="text-gray-400">
                {!locationShown && showShipName && shipNameText ? `- ${shipNameText}` : `[${tickerText}]`}
              </span>
            </div>
          </div>
          {shipType && (
            <div
              className="text-gray-300 overflow-hidden text-ellipsis whitespace-nowrap flex-shrink-0"
              style={{ maxWidth: '120px' }}
              title={shipType}
            >
              {shipType}
            </div>
          )}
        </div>
      </div>
    );
  }

  return (
    <div className={clsx('w-full text-xs box-border')} onClick={handleSelect}>
      <div className="w-full flex items-center gap-2">
        <CharacterPortrait characterEveId={char.eve_id} size={CharacterPortraitSize.w33} />
        <div className="flex flex-col flex-grow overflow-hidden">
          <div className="overflow-hidden text-ellipsis whitespace-nowrap">
            <span className={clsx(isOwn ? 'text-orange-400' : 'text-gray-200')}>{char.name}</span>{' '}
            <span className="text-gray-400">[{tickerText}]</span>
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
          <div className="flex-shrink-0 self-start">
            <div
              className="text-gray-300 overflow-hidden text-ellipsis whitespace-nowrap"
              style={{ maxWidth: '200px' }}
              title={shipType}
            >
              {shipType}
            </div>
          </div>
        )}
      </div>
    </div>
  );
};
