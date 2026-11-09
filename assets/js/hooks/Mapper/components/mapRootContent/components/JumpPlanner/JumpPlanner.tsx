import { isPossibleSpace } from '@/hooks/Mapper/components/map/helpers/isKnownSpace.ts';
import {
  SystemViewStandalone,
  TooltipPosition,
  WdButton,
  WdCheckbox,
  WdTooltipWrapper,
} from '@/hooks/Mapper/components/ui-kit';
import { useMapRootState } from '@/hooks/Mapper/mapRootProvider';
import { getSystemStaticInfo } from '@/hooks/Mapper/mapRootProvider/hooks/useLoadSystemStatic.ts';
import { OutCommand, SearchSystemItem } from '@/hooks/Mapper/types';
import { AutoComplete } from 'primereact/autocomplete';
import { Dropdown } from 'primereact/dropdown';
import { Sidebar } from 'primereact/sidebar';
import { RefObject, useCallback, useEffect, useMemo, useRef, useState } from 'react';
import clsx from 'clsx';
import classes from './JumpPlanner.module.scss';
import {
  JUMP_PLANNER_DESTINATION_SPACE,
  JUMP_PLANNER_FROM_SPACE,
  JUMP_SHIP_GROUPS,
  JumpPlannerField,
} from './constants.ts';
import { DEFAULT_JUMP_PLANNER_SETTINGS } from '@/hooks/Mapper/mapRootProvider/constants.ts';
import { JumpSkillLevelSelect } from './JumpSkillLevelSelect.tsx';
import { getJumpPlannerUrl } from './getJumpPlannerUrl.ts';

const SYSTEM_SEARCH_MIN_LENGTH = 2;
const DOTLAN_COOKIE_WARNING =
  'DOTLAN may still apply preferences stored in its cookies when these options are unchecked. Clear the corresponding saved preferences on DOTLAN if the generated route does not match these settings.';

interface JumpShipGroupOption {
  label: string;
}

const renderShipGroup = ({ label }: JumpShipGroupOption) => {
  return (
    <div className="flex items-center gap-2 py-1">
      <span className="shrink-0 text-[11px] font-semibold uppercase tracking-wide text-sky-300">{label}</span>
      <span className="h-px flex-1 bg-neutral-700" />
    </div>
  );
};

const renderShipOption = ({ label }: JumpShipGroupOption) => {
  return <span className="block pl-3 text-sm text-stone-200">{label}</span>;
};

const toSearchSystemItem = (system: SearchSystemItem['system_static_info']): SearchSystemItem => {
  return {
    class_title: system.class_title,
    constellation_name: system.constellation_name,
    label: system.solar_system_name,
    region_name: system.region_name,
    system_static_info: system,
    value: system.solar_system_id,
  };
};

const getInitialSystem = (systemId: string | null, allowedSystemClasses: number[]): SearchSystemItem | null => {
  if (!systemId) {
    return null;
  }

  const system = getSystemStaticInfo(systemId);
  if (!system || !isPossibleSpace(allowedSystemClasses, system.system_class)) {
    return null;
  }

  return toSearchSystemItem(system);
};

const renderSystem = (item: SearchSystemItem) => {
  const system = item.system_static_info;
  return (
    <SystemViewStandalone
      security={system.security}
      system_class={system.system_class}
      solar_system_id={item.value}
      class_title={item.class_title}
      solar_system_name={item.label}
      region_name={item.region_name}
    />
  );
};

export interface SystemSearchProps {
  id: string;
  inputRef: RefObject<AutoComplete>;
  value: SearchSystemItem | null;
  placeholder: string;
  allowedSystemClasses: number[];
  onChange(value: SearchSystemItem | null): void;
}

export const SystemSearch = ({
  id,
  inputRef,
  value,
  placeholder,
  allowedSystemClasses,
  onChange,
}: SystemSearchProps) => {
  const { outCommand } = useMapRootState();
  const [suggestions, setSuggestions] = useState<SearchSystemItem[]>([]);

  const searchSystems = useCallback(
    async ({ query }: { query: string }) => {
      if (query.length < SYSTEM_SEARCH_MIN_LENGTH) {
        setSuggestions([]);
        return;
      }

      try {
        const result = await outCommand<{ systems: SearchSystemItem[] }>({
          type: OutCommand.searchSystems,
          data: { text: query },
        });
        const normalizedQuery = query.toLowerCase();
        const systems = result.systems
          .filter(item => isPossibleSpace(allowedSystemClasses, item.system_static_info.system_class))
          .sort((a, b) => {
            return a.label.toLowerCase().indexOf(normalizedQuery) - b.label.toLowerCase().indexOf(normalizedQuery);
          });

        setSuggestions(systems);
      } catch (error) {
        console.error('Error fetching systems for Jump Planner:', error);
        setSuggestions([]);
      }
    },
    [allowedSystemClasses, outCommand],
  );

  return (
    <AutoComplete
      ref={inputRef}
      inputId={id}
      value={value ? [value] : []}
      suggestions={suggestions}
      completeMethod={searchSystems}
      onChange={event => {
        const selectedSystems = event.value as SearchSystemItem[];
        onChange(selectedSystems[selectedSystems.length - 1] ?? null);
      }}
      field="label"
      placeholder={placeholder}
      emptyMessage="Not found any system..."
      showEmptyMessage
      minLength={SYSTEM_SEARCH_MIN_LENGTH}
      scrollHeight="300px"
      autoComplete="off"
      forceSelection
      multiple
      className={clsx(classes.SystemSearch, 'flex h-10 w-full')}
      itemTemplate={renderSystem}
      selectedItemTemplate={renderSystem}
    />
  );
};

export interface JumpPlannerInitialSystem {
  field: JumpPlannerField;
  systemId: string;
}

export interface JumpPlannerProps {
  visible: boolean;
  initialSystem: JumpPlannerInitialSystem | null;
  onHide(): void;
}

export const JumpPlanner = ({ visible, initialSystem, onHide }: JumpPlannerProps) => {
  const {
    storedSettings: { settingsJumpPlanner, settingsJumpPlannerUpdate },
  } = useMapRootState();
  const fromInputRef = useRef<AutoComplete>(null);
  const destinationInputRef = useRef<AutoComplete>(null);
  const selectedSystem = useMemo(() => {
    let allowedSystemClasses = JUMP_PLANNER_FROM_SPACE;
    if (initialSystem?.field === JumpPlannerField.Destination) {
      allowedSystemClasses = JUMP_PLANNER_DESTINATION_SPACE;
    }

    return getInitialSystem(initialSystem?.systemId ?? null, allowedSystemClasses);
  }, [initialSystem?.field, initialSystem?.systemId]);
  const [source, setSource] = useState<SearchSystemItem | null>(null);
  const [destination, setDestination] = useState<SearchSystemItem | null>(null);

  useEffect(() => {
    if (!visible) {
      return;
    }

    if (initialSystem == null) {
      setSource(null);
      setDestination(null);
      return;
    }

    if (initialSystem?.field === JumpPlannerField.From) {
      setSource(selectedSystem);
      setDestination(null);
    } else {
      setSource(null);
      setDestination(selectedSystem);
    }
  }, [initialSystem, selectedSystem, visible]);

  const handleShow = useCallback(() => {
    if (initialSystem?.field === JumpPlannerField.From) {
      destinationInputRef.current?.focus();
      return;
    }

    fromInputRef.current?.focus();
  }, [initialSystem?.field]);

  const plannerSettings = useMemo(
    () => ({ ...DEFAULT_JUMP_PLANNER_SETTINGS, ...settingsJumpPlanner }),
    [settingsJumpPlanner],
  );
  const canOpen =
    source != null &&
    destination != null &&
    isPossibleSpace(JUMP_PLANNER_DESTINATION_SPACE, destination.system_static_info.system_class);

  const handleOpen = useCallback(() => {
    if (!source || !destination) {
      return;
    }

    const url = getJumpPlannerUrl(plannerSettings, source.label, destination.label);
    window.open(url, '_blank', 'noopener,noreferrer');
  }, [destination, plannerSettings, source]);

  return (
    <Sidebar
      className={clsx(classes.Sidebar, 'w-[600px] !p-0 bg-neutral-900')}
      visible={visible}
      position="right"
      onShow={handleShow}
      onHide={onHide}
      header="Jump Planner"
      icons={<></>}
    >
      <form
        className="flex flex-col gap-4 px-3 pb-3 pt-1"
        onSubmit={event => {
          event.preventDefault();
          handleOpen();
        }}
      >
        <div className="grid grid-cols-[1fr_1fr] items-end gap-2">
          <label className="flex min-w-0 flex-col gap-1.5 text-xs text-stone-400" htmlFor="jump-planner-from">
            <span>From</span>
            <SystemSearch
              id="jump-planner-from"
              inputRef={fromInputRef}
              value={source}
              placeholder="Type system name..."
              allowedSystemClasses={JUMP_PLANNER_FROM_SPACE}
              onChange={setSource}
            />
          </label>

          <label className="flex min-w-0 flex-col gap-1.5 text-xs text-stone-400" htmlFor="jump-planner-destination">
            <span>Destination</span>
            <SystemSearch
              id="jump-planner-destination"
              inputRef={destinationInputRef}
              value={destination}
              placeholder="Type system name..."
              allowedSystemClasses={JUMP_PLANNER_DESTINATION_SPACE}
              onChange={setDestination}
            />
          </label>
        </div>

        <label className="flex min-w-0 flex-col gap-1.5 text-xs text-stone-400" htmlFor="jump-planner-ship-type">
          <span>Ship Type</span>
          <Dropdown
            id="jump-planner-ship-type"
            value={plannerSettings.shipType}
            options={JUMP_SHIP_GROUPS}
            optionLabel="label"
            optionValue="value"
            optionGroupLabel="label"
            optionGroupChildren="items"
            optionGroupTemplate={renderShipGroup}
            itemTemplate={renderShipOption}
            onChange={event => settingsJumpPlannerUpdate(current => ({ ...current, shipType: event.value }))}
            className={clsx(classes.ShipSelect, 'flex h-10 w-full items-center')}
            scrollHeight="350px"
          />
        </label>

        <div className="grid grid-cols-3 gap-8">
          <JumpSkillLevelSelect
            id="jump-planner-jdc"
            label="Jump Drive Calibration"
            value={plannerSettings.jumpDriveCalibration}
            accent="sky"
            onChange={jumpDriveCalibration =>
              settingsJumpPlannerUpdate(current => ({ ...current, jumpDriveCalibration }))
            }
          />
          <JumpSkillLevelSelect
            id="jump-planner-jfc"
            label="Jump Fuel Conservation"
            value={plannerSettings.jumpFuelConservation}
            accent="emerald"
            onChange={jumpFuelConservation =>
              settingsJumpPlannerUpdate(current => ({ ...current, jumpFuelConservation }))
            }
          />
          <JumpSkillLevelSelect
            id="jump-planner-jf"
            label="Jump Freighter"
            value={plannerSettings.jumpFreighter}
            accent="violet"
            onChange={jumpFreighter => settingsJumpPlannerUpdate(current => ({ ...current, jumpFreighter }))}
          />
        </div>

        <div className="flex items-center gap-6">
          <WdCheckbox
            id="jump-planner-prefer-stations"
            label="Prefer Station Systems"
            value={plannerSettings.preferStationSystems}
            size="m"
            classNameLabel="text-xs text-stone-300"
            onChange={event =>
              settingsJumpPlannerUpdate(current => ({
                ...current,
                preferStationSystems: event.checked ?? false,
              }))
            }
          />
          <WdCheckbox
            id="jump-planner-avoid-incursions"
            label="Avoid Incursions"
            value={plannerSettings.avoidIncursions}
            size="m"
            classNameLabel="text-xs text-stone-300"
            onChange={event =>
              settingsJumpPlannerUpdate(current => ({
                ...current,
                avoidIncursions: event.checked ?? false,
              }))
            }
          />
          <WdTooltipWrapper
            content={DOTLAN_COOKIE_WARNING}
            position={TooltipPosition.top}
            tooltipClassName="max-w-80 whitespace-normal"
          >
            <i
              className="pi pi-info-circle cursor-help text-sm text-amber-400/80"
              aria-label="Information about saved DOTLAN preferences"
            />
          </WdTooltipWrapper>
        </div>

        <div className="flex items-center justify-end gap-3">
          <WdButton
            type="submit"
            outlined
            size="small"
            label="Open in Dotlan"
            icon="pi pi-external-link"
            disabled={!canOpen}
            className="h-9 shrink-0"
          />
        </div>
      </form>
    </Sidebar>
  );
};
