import { useCallback, useMemo } from 'react';
import { Widget } from '@/hooks/Mapper/components/mapInterface/components';
import { useMapRootState } from '@/hooks/Mapper/mapRootProvider';
import { VirtualScroller, VirtualScrollerTemplateOptions } from 'primereact/virtualscroller';
import clsx from 'clsx';
import classes from './LocalCharacters.module.scss';
import { CharacterTypeRaw, WithIsOwnCharacter } from '@/hooks/Mapper/types';
import { CharacterCard, LayoutEventBlocker, WdCheckbox } from '@/hooks/Mapper/components/ui-kit';
import { sortCharacters } from '@/hooks/Mapper/components/mapInterface/helpers/sortCharacters.ts';
import useLocalStorageState from 'use-local-storage-state';
import { useMapCheckPermissions, useMapGetOption } from '@/hooks/Mapper/mapRootProvider/hooks/api';
import { UserPermission } from '@/hooks/Mapper/types/permissions.ts';

type CharItemProps = {
  compact: boolean;
} & CharacterTypeRaw &
  WithIsOwnCharacter;

const useItemTemplate = () => {
  const {
    data: { presentCharacters },
  } = useMapRootState();

  return useCallback(
    (char: CharItemProps, options: VirtualScrollerTemplateOptions) => {
      return (
        <div
          className={clsx(classes.CharacterRow, 'w-full box-border', {
            'surface-hover': options.odd,
            ['border-b border-gray-600 border-opacity-20']: !options.last,
            ['bg-green-500 hover:bg-green-700 transition duration-300 bg-opacity-10 hover:bg-opacity-10']: char.online,
          })}
          style={{ height: options.props.itemSize + 'px' }}
        >
          <CharacterCard showShipName {...char} />
        </div>
      );
    },
    // eslint-disable-next-line
    [presentCharacters],
  );
};

type WindowLocalSettingsType = {
  compact: boolean;
  showOffline: boolean;
  version: number;
};

const STORED_DEFAULT_VALUES: WindowLocalSettingsType = {
  compact: true,
  showOffline: false,
  version: 0,
};

export const LocalCharacters = () => {
  const {
    data: { characters, userCharacters, selectedSystems, presentCharacters },
  } = useMapRootState();

  const [settings, setSettings] = useLocalStorageState<WindowLocalSettingsType>('window:local:settings', {
    defaultValue: STORED_DEFAULT_VALUES,
  });

  const [systemId] = selectedSystems;

  const restrictOfflineShowing = useMapGetOption('restrict_offline_showing');
  const isAdminOrManager = useMapCheckPermissions([UserPermission.MANAGE_MAP]);

  const showOffline = useMemo(
    () => !restrictOfflineShowing || isAdminOrManager,
    [isAdminOrManager, restrictOfflineShowing],
  );

  const itemTemplate = useItemTemplate();

  const sorted = useMemo(() => {
    const sorted = characters
      .filter(x => x.location?.solar_system_id?.toString() === systemId)
      .map(x => ({ ...x, isOwn: userCharacters.includes(x.eve_id), compact: settings.compact }))
      .sort(sortCharacters);

    if (!showOffline || !settings.showOffline) {
      return sorted.filter(c => c.online);
    }

    return sorted;
    // eslint-disable-next-line
  }, [showOffline, characters, settings.showOffline, settings.compact, systemId, userCharacters, presentCharacters]);

  const isNobodyHere = sorted.length === 0;
  const isNotSelectedSystem = selectedSystems.length !== 1;
  const showList = sorted.length > 0 && selectedSystems.length === 1;

  return (
    <Widget
      label={
        <div className="flex justify-between items-center text-xs w-full">
          <span className="select-none">Local{showList ? ` [${sorted.length}]` : ''}</span>
          <LayoutEventBlocker className="flex items-center gap-2">
            {showOffline && (
              <WdCheckbox
                size="xs"
                labelSide="left"
                label={'Show offline'}
                value={settings.showOffline}
                classNameLabel="text-stone-400 hover:text-stone-200 transition duration-300"
                onChange={() => setSettings(() => ({ ...settings, showOffline: !settings.showOffline }))}
              />
            )}

            <span
              className={clsx('w-4 h-4 cursor-pointer', {
                ['hero-bars-2']: settings.compact,
                ['hero-bars-3']: !settings.compact,
              })}
              onClick={() => setSettings(() => ({ ...settings, compact: !settings.compact }))}
            ></span>
          </LayoutEventBlocker>
        </div>
      }
    >
      {isNotSelectedSystem && (
        <div className="w-full h-full flex justify-center items-center select-none text-center text-stone-400/80 text-sm">
          System is not selected
        </div>
      )}

      {isNobodyHere && !isNotSelectedSystem && (
        <div className="w-full h-full flex justify-center items-center select-none text-stone-400/80 text-sm">
          Nobody here
        </div>
      )}

      {showList && (
        <VirtualScroller
          items={sorted}
          itemSize={settings.compact ? 26 : 41}
          itemTemplate={itemTemplate}
          className={clsx(
            classes.VirtualScroller,
            'w-full h-full overflow-x-hidden overflow-y-auto custom-scrollbar select-none',
          )}
          autoSize={false}
        />
      )}
    </Widget>
  );
};
