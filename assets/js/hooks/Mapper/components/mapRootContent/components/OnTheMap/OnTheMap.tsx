import classes from './OnTheMap.module.scss';
import { Sidebar } from 'primereact/sidebar';
import { useMemo, useState } from 'react';
import { useMapRootState } from '@/hooks/Mapper/mapRootProvider';
import { sortCharacters } from '@/hooks/Mapper/components/mapInterface/helpers/sortCharacters.ts';
import { VirtualScroller, VirtualScrollerTemplateOptions } from 'primereact/virtualscroller';
import clsx from 'clsx';
import { CharacterTypeRaw, WithIsOwnCharacter } from '@/hooks/Mapper/types';
import { CharacterCard, TooltipPosition, WdCheckbox, WdImageSize, WdImgButton } from '@/hooks/Mapper/components/ui-kit';
import { useMapCheckPermissions, useMapGetOption } from '@/hooks/Mapper/mapRootProvider/hooks/api';
import { UserPermission } from '@/hooks/Mapper/types/permissions.ts';
import { InputText } from 'primereact/inputtext';
import { IconField } from 'primereact/iconfield';

const itemTemplate = (item: CharacterTypeRaw & WithIsOwnCharacter, options: VirtualScrollerTemplateOptions) => {
  const showAllyLogoPlaceholder = options.props.items?.some(x => x.alliance_id != null);

  return (
    <div
      className={clsx(classes.CharacterRow, 'w-full box-border px-2 py-1', {
        'surface-hover': options.odd,
        ['border-b border-gray-600 border-opacity-20']: !options.last,
        ['bg-green-500 hover:bg-green-700 transition duration-300 bg-opacity-10 hover:bg-opacity-10']: item.online,
      })}
      style={{ height: options.props.itemSize + 'px' }}
    >
      <CharacterCard
        showCorporationLogo
        showAllyLogo
        showAllyLogoPlaceholder={showAllyLogoPlaceholder}
        showSystem
        showTicker
        showShip
        {...item}
      />
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
    storedSettings: { settingsOnTheMap, settingsOnTheMapUpdate },
  } = useMapRootState();

  const [searchVal, setSearchVal] = useState('');

  const restrictOfflineShowing = useMapGetOption('restrict_offline_showing');
  const isAdminOrManager = useMapCheckPermissions([UserPermission.MANAGE_MAP]);

  const showOffline = useMemo(
    () => !restrictOfflineShowing || isAdminOrManager,
    [isAdminOrManager, restrictOfflineShowing],
  );

  const sorted = useMemo(() => {
    let out = characters.map(x => ({ ...x, isOwn: userCharacters.includes(x.eve_id) })).sort(sortCharacters);

    if (searchVal !== '') {
      out = out.filter(x => {
        const normalized = searchVal.toLowerCase();

        if (x.name.toLowerCase().includes(normalized)) {
          return true;
        }

        if (x.corporation_name.toLowerCase().includes(normalized)) {
          return true;
        }

        if (x.alliance_name?.toLowerCase().includes(normalized)) {
          return true;
        }

        if (x.corporation_ticker.toLowerCase().includes(normalized)) {
          return true;
        }

        if (x.alliance_ticker?.toLowerCase().includes(normalized)) {
          return true;
        }

        if (x.ship?.ship_name?.toLowerCase().includes(normalized)) {
          return true;
        }

        if (x.ship?.ship_type_info.name?.toLowerCase().includes(normalized)) {
          return true;
        }

        if (x.ship?.ship_type_info.group_name?.toLowerCase().includes(normalized)) {
          return true;
        }

        return false;
      });
    }

    if (showOffline && !settingsOnTheMap.hideOffline) {
      return out;
    }

    return out.filter(x => x.online);
  }, [showOffline, searchVal, characters, settingsOnTheMap.hideOffline, userCharacters]);

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
        <div className={'flex justify-between items-center gap-2 px-2 pt-1'}>
          <IconField>
            {searchVal.length > 0 && (
              <WdImgButton
                className="pi pi-trash"
                textSize={WdImageSize.large}
                tooltip={{
                  content: 'Clear',
                  className: 'pi p-input-icon',
                  position: TooltipPosition.top,
                }}
                onClick={() => setSearchVal('')}
              />
            )}
            <InputText
              id="label"
              aria-describedby="label"
              autoComplete="off"
              value={searchVal}
              placeholder="Type to search"
              onChange={e => setSearchVal(e.target.value)}
            />
          </IconField>

          {showOffline && (
            <WdCheckbox
              size="m"
              labelSide="left"
              label={'Hide offline'}
              value={settingsOnTheMap.hideOffline}
              classNameLabel="text-stone-400 hover:text-stone-200 transition duration-300"
              onChange={() =>
                settingsOnTheMapUpdate(() => ({ ...settingsOnTheMap, hideOffline: !settingsOnTheMap.hideOffline }))
              }
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
