import { useMemo, useRef, useState, useEffect } from 'react';
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

//
// A new responsive checkbox that adjusts its label and even removes itself
// if there isn’t enough space.
//
interface ResponsiveCheckboxProps {
  tooltipContent: string;
  size: string;
  labelFull: string;
  labelAbbreviated: string;
  value: boolean;
  onChange: () => void;
  classNameLabel?: string;
  containerClassName?: string;
  labelSide?: string;
}

const ResponsiveCheckbox: React.FC<ResponsiveCheckboxProps> = ({
  tooltipContent,
  size,
  labelFull,
  labelAbbreviated,
  value,
  onChange,
  classNameLabel,
  containerClassName,
  labelSide = 'left',
}) => {
  const containerRef = useRef<HTMLDivElement>(null);
  const [width, setWidth] = useState(0);

  useEffect(() => {
    if (!containerRef.current) return;
    const observer = new ResizeObserver((entries) => {
      for (let entry of entries) {
        setWidth(entry.contentRect.width);
      }
    });
    observer.observe(containerRef.current);
    return () => observer.disconnect();
  }, []);

  // Define breakpoints (adjust these values as needed):
  const FULL_LABEL_THRESHOLD = 150;       // full label (e.g. "Show offline")
  const ABBREVIATED_LABEL_THRESHOLD = 100;  // abbreviated label (e.g. "Offline")
  const MINIMUM_THRESHOLD = 50;             // only enough space for the checkbox icon

  let labelToShow: string;
  if (width === 0) {
    // Before we have a measurement, assume there's enough space.
    labelToShow = labelFull;
  } else if (width >= FULL_LABEL_THRESHOLD) {
    labelToShow = labelFull;
  } else if (width >= ABBREVIATED_LABEL_THRESHOLD) {
    labelToShow = labelAbbreviated;
  } else if (width >= MINIMUM_THRESHOLD) {
    labelToShow = ''; // show checkbox with no label
  } else {
    return null; // not enough space to show anything
  }

  const checkbox = (
    <div ref={containerRef} className={containerClassName}>
      <WdCheckbox
        size={size}
        labelSide={labelSide}
        label={labelToShow}
        value={value}
        classNameLabel={classNameLabel}
        onChange={onChange}
      />
    </div>
  );

  return tooltipContent ? (
    <WdTooltipWrapper content={tooltipContent}>{checkbox}</WdTooltipWrapper>
  ) : (
    checkbox
  );
};

//
// The main component with an updated header that uses ResponsiveCheckbox
//
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
                <ResponsiveCheckbox
                  tooltipContent="Show offline characters in system"
                  size="xs"
                  labelFull="Show offline"
                  labelAbbreviated="Offline"
                  value={settings.showOffline}
                  onChange={() =>
                    setSettings(prev => ({ ...prev, showOffline: !prev.showOffline }))
                  }
                  classNameLabel={clsx("whitespace-nowrap", { truncate: compact })}
                  // Updated container class to allow flex shrinking
                  containerClassName={clsx("min-w-0 flex-shrink", { "max-w-[100px]": compact })}
                />
              )}

              {settings.compact && (
                <ResponsiveCheckbox
                  tooltipContent="Show ship name in compact rows"
                  size="xs"
                  labelFull="Show ship name"
                  labelAbbreviated="Ship name"
                  value={settings.showShipName}
                  onChange={() =>
                    setSettings(prev => ({ ...prev, showShipName: !prev.showShipName }))
                  }
                  classNameLabel={clsx("whitespace-nowrap", { truncate: compact })}
                  // Updated container class to allow flex shrinking
                  containerClassName={clsx("min-w-0 flex-shrink", { "max-w-[100px]": compact })}
                />
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
