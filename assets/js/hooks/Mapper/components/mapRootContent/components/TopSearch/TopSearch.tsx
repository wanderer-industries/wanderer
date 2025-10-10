import classes from './TopSearch.module.scss';
import { Sidebar } from 'primereact/sidebar';
import React, { useCallback, useMemo, useRef, useState } from 'react';
import { useMapRootState } from '@/hooks/Mapper/mapRootProvider';
import { VirtualScroller, VirtualScrollerTemplateOptions } from 'primereact/virtualscroller';
import clsx from 'clsx';
import { Commands, SolarSystemRawType, SolarSystemStaticInfoRaw } from '@/hooks/Mapper/types';
import {
  SystemViewStandalone,
  TooltipPosition,
  WdImageSize,
  WdImgButton,
  WdTooltipWrapper,
  WHClassView,
  WHEffectView,
} from '@/hooks/Mapper/components/ui-kit';
import { InputText } from 'primereact/inputtext';
import { IconField } from 'primereact/iconfield';
import { getSystemStaticInfo } from '@/hooks/Mapper/mapRootProvider/hooks/useLoadSystemStatic.ts';
import { sortWHClasses } from '@/hooks/Mapper/helpers';
import { isWormholeSpace } from '@/hooks/Mapper/components/map/helpers/isWormholeSpace.ts';
import { STATUS_CLASSES } from '@/hooks/Mapper/components/map/constants.ts';
import { REGIONS_MAP, SPACE_TO_CLASS } from '@/hooks/Mapper/constants.ts';
import { emitMapEvent } from '@/hooks/Mapper/events';
import { LocalCounter } from '@/hooks/Mapper/components/map/components/LocalCounter';
import { getLocalCharacters } from '@/hooks/Mapper/components/hooks/useLocalCounter.ts';
import { PrimeIcons } from 'primereact/api';

type CompiledSystem = {
  dynamic: SolarSystemRawType;
  static: SolarSystemStaticInfoRaw | undefined;
};

const useItemTemplate = () => {
  const {
    data: { wormholesData, characters, userCharacters, hubs },
  } = useMapRootState();

  return useCallback(
    (item: CompiledSystem, options: VirtualScrollerTemplateOptions) => {
      if (!item.static) {
        return null;
      }

      const {
        security,
        system_class,
        class_title,
        effect_power,
        region_name,
        solar_system_name,
        solar_system_id,
        effect_name,
        statics,
        region_id,
      } = item.static;

      const onlineCharactersInSystem = characters.filter(
        c => c.location?.solar_system_id === solar_system_id && c.online,
      );
      const hasOnlineUserCharacters = onlineCharactersInSystem.some(x => userCharacters.includes(x.eve_id));
      const onlineCharacters = getLocalCharacters({ charactersInSystem: onlineCharactersInSystem, userCharacters });

      const offlineCharactersInSystem = characters.filter(
        c => c.location?.solar_system_id === solar_system_id && !c.online,
      );
      const hasOfflineUserCharacters = offlineCharactersInSystem.some(x => userCharacters.includes(x.eve_id));
      const offlineCharacters = getLocalCharacters({ charactersInSystem: offlineCharactersInSystem, userCharacters });

      const handleSelect = () => {
        emitMapEvent({
          name: Commands.centerSystem,
          data: solar_system_id.toString(),
        });
      };

      const sortedStatics = sortWHClasses(wormholesData, statics);
      const isWH = isWormholeSpace(system_class);

      const regionClass = SPACE_TO_CLASS[REGIONS_MAP[region_id]] || null;
      const showTempName = item.dynamic.temporary_name != null;
      const showCustomName = item.dynamic.name != null && item.dynamic.name !== solar_system_name;

      return (
        <div
          className={clsx(
            'w-full box-border px-3.5 py-1 h-[48px] cursor-pointer',
            'bg-transparent hover:bg-stone-800/30 transition-all !duration-250 ease-in-out',
            {
              'surface-hover': options.odd,
              ['border-b border-gray-600 border-opacity-20']: !options.last,
            },
            classes.Content,
            regionClass && classes[regionClass],
            item.dynamic.status !== undefined && classes[STATUS_CLASSES[item.dynamic.status]],
          )}
          onClick={handleSelect}
        >
          <div className={clsx('w-full')}>
            <div className={clsx('grid grid-cols-[1fr_auto] gap-1.5 w-full')}>
              <div className="flex [&>*]:!text-[13px] gap-1.5">
                <SystemViewStandalone
                  className="!text-[13px]"
                  security={security}
                  system_class={system_class}
                  solar_system_id={parseInt(item.dynamic.id)}
                  class_title={class_title}
                  solar_system_name={`${solar_system_name}`}
                  region_name={region_name}
                  nameClassName="font-semibold"
                />

                {(showTempName || showCustomName) && (
                  <div className="grid grid-cols-[auto_1fr] gap-1.5 text-stone-400 text-[12px]">
                    {showTempName && (
                      <span className="overflow-hidden text-ellipsis whitespace-nowrap">
                        {item.dynamic.temporary_name}
                      </span>
                    )}
                    {showCustomName && (
                      <span className="overflow-hidden text-ellipsis whitespace-nowrap">{item.dynamic.name}</span>
                    )}
                  </div>
                )}

                {effect_name && isWH && (
                  <WHEffectView
                    effectName={effect_name}
                    effectPower={effect_power}
                    className={classes.SearchItemEffect}
                  />
                )}
              </div>
              <div>
                {isWH && (
                  <div className="flex gap-1 grow justify-between !text-[13px]">
                    <div></div>
                    <div className="flex gap-1">
                      {sortedStatics.map(x => (
                        <WHClassView key={x} whClassName={x} />
                      ))}
                    </div>
                  </div>
                )}
              </div>
            </div>
            <div className="flex gap-1.5 text-[13px] pl-[2px] items-center h-[20px]">
              <LocalCounter
                disableInteractive
                className="[&_span]:!text-[12px] [&_i]:!text-[13px]"
                hasUserCharacters={hasOnlineUserCharacters}
                localCounterCharacters={onlineCharacters}
              />
              <LocalCounter
                disableInteractive
                className="[&_span]:!text-[12px] [&_i]:!text-[13px] text-stone-[400]"
                contentClassName={clsx('!text-stone-500', { ['!text-yellow-600']: hasOfflineUserCharacters })}
                hasUserCharacters={hasOfflineUserCharacters}
                localCounterCharacters={offlineCharacters}
              />
              {item.dynamic.locked && <i className={clsx(PrimeIcons.LOCK, 'text-[11px] relative top-[1px]')} />}
              {hubs.includes(solar_system_id.toString()) && (
                <i className={clsx(PrimeIcons.MAP_MARKER, 'text-[11px] relative top-[1px]')} />
              )}
              {item.dynamic.comments_count != null && item.dynamic.comments_count > 0 && (
                <WdTooltipWrapper
                  position={TooltipPosition.top}
                  content={`[${item.dynamic.comments_count}] Comments in System - click to system to see it in Comments Widget`}
                >
                  <i className={clsx(PrimeIcons.COMMENT, 'text-[11px] relative top-[1px]')} />
                </WdTooltipWrapper>
              )}
              {item.dynamic.description != null && item.dynamic.description !== '' && (
                <WdTooltipWrapper
                  position={TooltipPosition.top}
                  content={`System have description - click to system to see it in Info Widget`}
                >
                  <i
                    className={clsx(
                      'pi hero-chat-bubble-bottom-center-text w-[14px] h-[14px]',
                      'text-[8px] relative top-[-1px]',
                    )}
                  />
                </WdTooltipWrapper>
              )}
              {/*kek*/}
            </div>
          </div>
        </div>
      );
    },
    [characters, hubs, userCharacters, wormholesData],
  );
};

export interface TopSearchSidebarProps {
  show: boolean;
  onHide: () => void;
}

export const TopSearchSidebar = ({ show, onHide }: TopSearchSidebarProps) => {
  const [searchVal, setSearchVal] = useState('');

  // eslint-disable-next-line
  const inputRef = useRef<any>();

  const {
    data: { systems },
  } = useMapRootState();

  const itemTemplate = useItemTemplate();

  const systemsCompiled = useMemo<CompiledSystem[]>(() => {
    return systems.map(x => ({
      dynamic: x,
      static: getSystemStaticInfo(x.id),
    }));
  }, [systems]);

  const onShow = useCallback(() => {
    inputRef.current?.focus();
  }, []);

  const filtered = useMemo(() => {
    let out = systemsCompiled;

    out = out.sort((a, b) => {
      // 1. Status > 0 — always on top and ASC
      if (a.dynamic.status > 0 && b.dynamic.status > 0) return a.dynamic.status - b.dynamic.status;
      if (a.dynamic.status > 0) return -1;
      if (b.dynamic.status > 0) return 1;

      // 2. IF status = 0, J priority
      const aStartsWithJ = a.dynamic.name?.startsWith('J') ?? false;
      const bStartsWithJ = b.dynamic.name?.startsWith('J') ?? false;

      if (aStartsWithJ && !bStartsWithJ) return -1;
      if (!aStartsWithJ && bStartsWithJ) return 1;

      // 3. IF both starts with J or not - sort by name
      const nameA = a.dynamic.name ?? '';
      const nameB = b.dynamic.name ?? '';
      return nameA.localeCompare(nameB);
    });

    const normalized = searchVal.toLowerCase();

    if (searchVal !== '') {
      out = out.filter(x => {
        if (x.static?.solar_system_name.toLowerCase().includes(normalized)) {
          return true;
        }

        if (x.dynamic.name?.toLowerCase().includes(normalized)) {
          return true;
        }

        if (x.dynamic.temporary_name?.toLowerCase().includes(normalized)) {
          return true;
        }

        return false;
      });
    }

    return out;
  }, [searchVal, systemsCompiled]);

  return (
    <Sidebar
      className={clsx(classes.Sidebar, 'bg-neutral-900 !p-[0px] w-[500px]')}
      visible={show}
      position="right"
      onShow={onShow}
      onHide={onHide}
      modal={false}
      header={`Search [${filtered.length}]`}
      icons={<></>}
    >
      <div className={clsx('grid grid-rows-[auto_1fr] gap-y-[8px] h-full')}>
        <div className={'flex justify-between items-center gap-2 px-2 pt-1'}>
          <IconField className="w-full">
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
              className="w-full"
              aria-describedby="label"
              ref={inputRef}
              autoComplete="off"
              value={searchVal}
              placeholder="Type To Search"
              onChange={e => setSearchVal(e.target.value)}
            />
          </IconField>
        </div>

        <VirtualScroller
          items={filtered}
          itemSize={48}
          itemTemplate={itemTemplate}
          className={clsx(
            classes.VirtualScroller,
            'w-full h-full overflow-x-hidden overflow-y-auto custom-scrollbar select-none',
            '[&>div]:w-full',
          )}
          autoSize={false}
        />
      </div>
    </Sidebar>
  );
};

interface TopSearchProps {
  customBtn?: (open: () => void) => React.ReactNode;
}

export const TopSearch = ({ customBtn }: TopSearchProps) => {
  const [openAddSystem, setOpenAddSystem] = useState<boolean>(false);

  return (
    <>
      {customBtn != null && customBtn(() => setOpenAddSystem(true))}
      {customBtn == null && (
        <button
          className="btn bg-transparent text-gray-400 hover:text-white border-transparent hover:bg-transparent px-2 relative left-1"
          type="button"
          onClick={() => setOpenAddSystem(true)}
        >
          <i className="pi pi-search text-lg"></i>
        </button>
      )}

      <TopSearchSidebar show={openAddSystem} onHide={() => setOpenAddSystem(false)} />
    </>
  );
};
