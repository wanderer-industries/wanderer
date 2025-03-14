import classes from './OnTheMap.module.scss';
import { Sidebar } from 'primereact/sidebar';
import { useMemo } from 'react';
import { useMapRootState } from '@/hooks/Mapper/mapRootProvider';
import { sortCharacters } from '@/hooks/Mapper/components/mapInterface/helpers/sortCharacters.ts';
import { VirtualScroller, VirtualScrollerTemplateOptions } from 'primereact/virtualscroller';
import clsx from 'clsx';
import { CharacterTypeRaw, WithIsOwnCharacter } from '@/hooks/Mapper/types';
import { CharacterCard, WdCheckbox } from '@/hooks/Mapper/components/ui-kit';
import useLocalStorageState from 'use-local-storage-state';
import { useMapCheckPermissions, useMapGetOption } from '@/hooks/Mapper/mapRootProvider/hooks/api';
import { UserPermission } from '@/hooks/Mapper/types/permissions.ts';

type WindowLocalSettingsType = {
  compact: boolean;
  hideOffline: boolean;
  version: number;
};

const STORED_DEFAULT_VALUES: WindowLocalSettingsType = {
  compact: true,
  hideOffline: false,
  version: 0,
};

const itemTemplate = (item: CharacterTypeRaw & WithIsOwnCharacter, options: VirtualScrollerTemplateOptions) => {
  return (
    <div
      className={clsx(classes.CharacterRow, 'w-full box-border px-2 py-1', {
        'surface-hover': options.odd,
        ['border-b border-gray-600 border-opacity-20']: !options.last,
        ['bg-green-500 hover:bg-green-700 transition duration-300 bg-opacity-10 hover:bg-opacity-10']: item.online,
      })}
      style={{ height: options.props.itemSize + 'px' }}
    >
      <CharacterCard showSystem {...item} />
    </div>
  );
};

export interface OnTheMapProps {
  show: boolean;
  onHide: () => void;
}

export const OnTheMap = ({ show, onHide }: OnTheMapProps) => {
  const {
    data: { characters, userCharacters },
  } = useMapRootState();

  const [settings, setSettings] = useLocalStorageState<WindowLocalSettingsType>('window:onTheMap:settings', {
    defaultValue: STORED_DEFAULT_VALUES,
  });

  const restrictOfflineShowing = useMapGetOption('restrict_offline_showing');
  const isAdminOrManager = useMapCheckPermissions([UserPermission.MANAGE_MAP]);

  const showOffline = useMemo(
    () => !restrictOfflineShowing || isAdminOrManager,
    [isAdminOrManager, restrictOfflineShowing],
  );

  const sorted = useMemo(() => {
    const out = characters.map(x => ({ ...x, isOwn: userCharacters.includes(x.eve_id) })).sort(sortCharacters);
    if (showOffline && !settings.hideOffline) {
      return out;
    }

    return out.filter(x => x.online);
  }, [showOffline, characters, settings.hideOffline, userCharacters]);

  return (
    <Sidebar
      className={clsx(classes.SidebarOnTheMap, 'bg-neutral-900')}
      visible={show}
      position="right"
      onHide={onHide}
      header={`On the map [${sorted.length}]`}
      icons={<></>}
    >
      <div className={clsx(classes.SidebarContent, '')}>
        <div className={'flex justify-end items-center gap-2 px-3'}>
          {showOffline && (
            <WdCheckbox
              size="m"
              labelSide="left"
              label={'Hide offline'}
              value={settings.hideOffline}
              classNameLabel="text-stone-400 hover:text-stone-200 transition duration-300"
              onChange={() => setSettings(() => ({ ...settings, hideOffline: !settings.hideOffline }))}
            />
          )}
        </div>

        <VirtualScroller
          items={sorted}
          itemSize={41}
          itemTemplate={itemTemplate}
          className={clsx(
            classes.VirtualScroller,
            'w-full h-full overflow-x-hidden overflow-y-auto custom-scrollbar select-none',
          )}
          autoSize={false}
        />
      </div>
    </Sidebar>
  );
};
