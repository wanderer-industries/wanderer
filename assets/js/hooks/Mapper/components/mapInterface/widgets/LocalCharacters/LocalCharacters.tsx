import { useMemo, useRef } from 'react';
import { Widget } from '@/hooks/Mapper/components/mapInterface/components';
import { useMapRootState } from '@/hooks/Mapper/mapRootProvider';
import clsx from 'clsx';
import { LayoutEventBlocker, WdCheckbox } from '@/hooks/Mapper/components/ui-kit';
import { sortCharacters } from '@/hooks/Mapper/components/mapInterface/helpers/sortCharacters.ts';
import useLocalStorageState from 'use-local-storage-state';
import { useMapCheckPermissions, useMapGetOption } from '@/hooks/Mapper/mapRootProvider/hooks/api';
import { UserPermission } from '@/hooks/Mapper/types/permissions.ts';
import useMaxWidth from '@/hooks/Mapper/hooks/useMaxWidth.ts';
import { WdTooltipWrapper } from '@/hooks/Mapper/components/ui-kit/WdTooltipWrapper';
import { LocalCharactersList } from './components/LocalCharactersList';
import { useLocalCharactersItemTemplate } from './hooks/useLocalCharacters';
import { WindowLocalSettingsType, STORED_DEFAULT_VALUES } from './components';

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

  const sorted = useMemo(() => {
    const filtered = characters
      .filter(x => x.location?.solar_system_id?.toString() === systemId)
      .map(x => ({
        ...x,
        isOwn: userCharacters.includes(x.eve_id),
        compact: settings.compact,
      }))
      .sort(sortCharacters);

    if (!showOffline || !settings.showOffline) {
      return filtered.filter(c => c.online);
    }

    return filtered;
  }, [showOffline, characters, settings.showOffline, settings.compact, systemId, userCharacters]);

  const isNobodyHere = sorted.length === 0;
  const isNotSelectedSystem = selectedSystems.length !== 1;
  const showList = sorted.length > 0 && selectedSystems.length === 1;

  const ref = useRef<HTMLDivElement>(null);
  const compact = useMaxWidth(ref, 145);

  const itemTemplate = useLocalCharactersItemTemplate();

  return (
    <Widget
      label={
        <div className="flex justify-between items-center text-xs w-full" ref={ref}>
          <span className="select-none">Local{showList ? ` [${sorted.length}]` : ''}</span>
          <LayoutEventBlocker className="flex items-center gap-2">
            {showOffline && (
              <WdTooltipWrapper content="Show offline characters in system">
                <WdCheckbox
                  size="xs"
                  labelSide="left"
                  label={compact ? '' : 'Show offline'}
                  value={settings.showOffline}
                  classNameLabel="text-stone-400 hover:text-stone-200 transition duration-300"
                  onChange={() => setSettings(prev => ({ ...prev, showOffline: !prev.showOffline }))}
                />
              </WdTooltipWrapper>
            )}

            <span
              className={clsx('w-4 h-4 cursor-pointer', {
                ['hero-bars-2']: settings.compact,
                ['hero-bars-3']: !settings.compact,
              })}
              onClick={() => setSettings(prev => ({ ...prev, compact: !prev.compact }))}
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
        <LocalCharactersList
          items={sorted}
          itemSize={40}
          itemTemplate={itemTemplate}
          containerClassName="w-full h-full overflow-x-hidden overflow-y-auto"
        />
      )}
    </Widget>
  );
};
