import { useMemo } from 'react';
import { Widget } from '@/hooks/Mapper/components/mapInterface/components';
import { useMapRootState } from '@/hooks/Mapper/mapRootProvider';
import { sortCharacters } from '@/hooks/Mapper/components/mapInterface/helpers/sortCharacters';
import { useMapCheckPermissions, useMapGetOption } from '@/hooks/Mapper/mapRootProvider/hooks/api';
import { UserPermission } from '@/hooks/Mapper/types/permissions';
import { LocalCharactersList } from './components/LocalCharactersList';
import { useLocalCharactersItemTemplate } from './hooks/useLocalCharacters';
import { useLocalCharacterWidgetSettings } from './hooks/useLocalWidgetSettings';
import { LocalCharactersHeader } from './components/LocalCharactersHeader';
import classes from './LocalCharacters.module.scss';
import clsx from 'clsx';

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

  const itemTemplate = useLocalCharactersItemTemplate(settings.showShipName);

  return (
    <Widget
      label={
        <LocalCharactersHeader
          sortedCount={sorted.length}
          showList={showList}
          showOffline={showOffline}
          settings={settings}
          setSettings={setSettings}
        />
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
          containerClassName={clsx(
            'w-full h-full overflow-x-hidden overflow-y-auto custom-scrollbar select-none',
            classes.VirtualScroller,
          )}
        />
      )}
    </Widget>
  );
};
