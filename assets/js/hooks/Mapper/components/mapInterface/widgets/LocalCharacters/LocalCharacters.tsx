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
        <div className="flex w-full items-center text-xs" ref={ref}>
          <div className="flex-shrink-0 select-none mr-2">
            Local{showList ? ` [${sorted.length}]` : ''}
          </div>
          <div className="flex-grow overflow-hidden">
            <LayoutEventBlocker className="flex items-center gap-2 justify-end">
              {showOffline && (
                <WdTooltipWrapper content="Show offline characters in system">
                  <div className={clsx("min-w-0", { "max-w-[100px]": compact })}>
                    <WdCheckbox
                      size="xs"
                      labelSide="left"
                      label="Show offline"
                      value={settings.showOffline}
                      classNameLabel={clsx("whitespace-nowrap", { "truncate": compact })}
                      onChange={() =>
                        setSettings(prev => ({ ...prev, showOffline: !prev.showOffline }))
                      }
                    />
                  </div>
                </WdTooltipWrapper>
              )}

              {settings.compact && (
                <WdTooltipWrapper content="Show ship name in compact rows">
                  <div className={clsx("min-w-0", { "max-w-[100px]": compact })}>
                    <WdCheckbox
                      size="xs"
                      labelSide="left"
                      label="Show ship name"
                      value={settings.showShipName}
                      classNameLabel={clsx("whitespace-nowrap", { "truncate": compact })}
                      onChange={() =>
                        setSettings(prev => ({ ...prev, showShipName: !prev.showShipName }))
                      }
                    />
                  </div>
                </WdTooltipWrapper>
              )}

              <span
                className={clsx("w-4 h-4 cursor-pointer", {
                  "hero-bars-2": settings.compact,
                  "hero-bars-3": !settings.compact,
                })}
                onClick={() => setSettings(prev => ({ ...prev, compact: !prev.compact }))}
              />
            </LayoutEventBlocker>
          </div>
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
          containerClassName="w-full h-full overflow-x-hidden overflow-y-auto custom-scrollbar select-none"
        />
      )}
    </Widget>
  );
};
