import { useMemo, useRef } from 'react';
import { Widget } from '@/hooks/Mapper/components/mapInterface/components';
import { useMapRootState } from '@/hooks/Mapper/mapRootProvider';
import clsx from 'clsx';
import { LayoutEventBlocker, WdCheckbox } from '@/hooks/Mapper/components/ui-kit';
import { sortCharacters } from '@/hooks/Mapper/components/mapInterface/helpers/sortCharacters.ts';
import { useMapCheckPermissions, useMapGetOption } from '@/hooks/Mapper/mapRootProvider/hooks/api';
import { UserPermission } from '@/hooks/Mapper/types/permissions.ts';
import useMaxWidth from '@/hooks/Mapper/hooks/useMaxWidth.ts';
import { WdTooltipWrapper } from '@/hooks/Mapper/components/ui-kit/WdTooltipWrapper';
import { LocalCharactersList } from './components/LocalCharactersList';
import { useLocalCharactersItemTemplate } from './hooks/useLocalCharacters';
import { useLocalCharacterWidgetSettings } from './hooks/useLocalWidgetSettings';

export const LocalCharacters = () => {
  const {
    data: { characters, userCharacters, selectedSystems },
  } = useMapRootState();

  const [settings, setSettings] = useLocalCharacterWidgetSettings();

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
        showShipName: settings.showShipName,
      }))
      .sort(sortCharacters);

    if (!showOffline || !settings.showOffline) {
      return filtered.filter(c => c.online);
    }

    return filtered;
  }, [
    characters,
    systemId,
    userCharacters,
    settings.compact,
    settings.showOffline,
    settings.showShipName,
    showOffline,
  ]);

  const isNobodyHere = sorted.length === 0;
  const isNotSelectedSystem = selectedSystems.length !== 1;
  const showList = sorted.length > 0 && selectedSystems.length === 1;

  const ref = useRef<HTMLDivElement>(null);
  const compact = useMaxWidth(ref, 145);

  const itemTemplate = useLocalCharactersItemTemplate(settings.showShipName);

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

            {settings.compact && (
              <WdTooltipWrapper content="Show ship name in compact rows">
                <WdCheckbox
                  size="xs"
                  labelSide="left"
                  label={compact ? '' : 'Show ship name'}
                  value={settings.showShipName}
                  classNameLabel="text-stone-400 hover:text-stone-200 transition duration-300"
                  onChange={() => setSettings(prev => ({ ...prev, showShipName: !prev.showShipName }))}
                />
              </WdTooltipWrapper>
            )}

            <span
              className={clsx('w-4 h-4 cursor-pointer', {
                ['hero-bars-2']: settings.compact,
                ['hero-bars-3']: !settings.compact,
              })}
              onClick={() => setSettings(prev => ({ ...prev, compact: !prev.compact }))}
            />
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
          itemSize={settings.compact ? 26 : 41}
          itemTemplate={itemTemplate}
          containerClassName="w-full h-full overflow-x-hidden overflow-y-auto"
        />
      )}
    </Widget>
  );
};
