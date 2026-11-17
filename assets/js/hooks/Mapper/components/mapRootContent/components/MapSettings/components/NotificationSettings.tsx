import { useCallback, useState } from 'react';
import { Dropdown } from 'primereact/dropdown';

import { SystemView, WdCheckbox, WdSystemSelectionDialog, WdTagInput } from '@/hooks/Mapper/components/ui-kit';
import { AddSystemDialog } from '@/hooks/Mapper/components/mapInterface/components/AddSystemDialog';
import { useMapRootState } from '@/hooks/Mapper/mapRootProvider';
import { InterfaceStoredSettings, KillNotificationScope } from '@/hooks/Mapper/mapRootProvider/types.ts';
import { DEFAULT_KILL_NOTIFICATION_SCOPES } from '@/hooks/Mapper/mapRootProvider/constants.ts';
import { SearchSystemItem } from '@/hooks/Mapper/types';
import { PrettySwitchbox } from './PrettySwitchbox';

const KILL_NOTIFICATION_SCOPE_OPTIONS = [
  { value: KillNotificationScope.wormhole, label: 'Wormholes' },
  { value: KillNotificationScope.highSec, label: 'High-sec' },
  { value: KillNotificationScope.lowSec, label: 'Low-sec' },
  { value: KillNotificationScope.nullSec, label: 'Null-sec' },
  { value: KillNotificationScope.pochven, label: 'Pochven' },
  { value: KillNotificationScope.other, label: 'Other' },
];

const KILL_NOTIFICATION_TOAST_LIFETIME_OPTIONS = [
  { value: 5, label: '5 seconds' },
  { value: 10, label: '10 seconds' },
  { value: 30, label: '30 seconds' },
  { value: 60, label: '1 minute' },
  { value: 0, label: 'Until dismissed' },
];

export interface NotificationSettingsProps {}

// eslint-disable-next-line no-empty-pattern
export const NotificationSettings = ({}: NotificationSettingsProps) => {
  const {
    storedSettings: { interfaceSettings, setInterfaceSettings },
  } = useMapRootState();
  const [systemDialogVisible, setSystemDialogVisible] = useState(false);
  const [systemSearchVisible, setSystemSearchVisible] = useState(false);
  const [draftExcludedSystems, setDraftExcludedSystems] = useState<number[]>([]);

  const excludedSystems = interfaceSettings.killActivityExcludedSystems ?? [];
  const selectedScopes = interfaceSettings.killActivityScopes ?? DEFAULT_KILL_NOTIFICATION_SCOPES;

  const updateSettings = useCallback(
    (patch: Partial<InterfaceStoredSettings>) => {
      setInterfaceSettings(current => ({ ...current, ...patch }));
    },
    [setInterfaceSettings],
  );

  const handleToggleScope = (scope: KillNotificationScope, checked: boolean) => {
    let nextScopes: KillNotificationScope[];

    if (checked) {
      nextScopes = [...new Set([...selectedScopes, scope])];
    } else {
      nextScopes = selectedScopes.filter(currentScope => currentScope !== scope);
    }

    updateSettings({ killActivityScopes: nextScopes });
  };

  const handleRemoveExcludedSystem = (systemId: number) => {
    updateSettings({
      killActivityExcludedSystems: excludedSystems.filter(currentId => currentId !== systemId),
    });
  };

  const handleOpenSystemDialog = () => {
    setDraftExcludedSystems(excludedSystems);
    setSystemDialogVisible(true);
  };

  const handleAddSystem = (system: SearchSystemItem) => {
    setDraftExcludedSystems(current => [...new Set([...current, system.value])]);
  };

  const handleApplyExcludedSystems = () => {
    updateSettings({ killActivityExcludedSystems: draftExcludedSystems });
    setSystemDialogVisible(false);
  };

  const handleHideSystemDialog = () => {
    setSystemSearchVisible(false);
    setSystemDialogVisible(false);
  };

  return (
    <div className="flex h-full w-full min-w-0 flex-col gap-3 overflow-hidden">
      <div className="flex items-center gap-3">
        <span className="text-[0.7rem] uppercase tracking-wider text-stone-500">Kills</span>
        <div className="h-px flex-1 bg-stone-700/70" />
      </div>

      <div className="flex flex-col gap-1">
        <PrettySwitchbox
          label="Show visual toast for map kill activity"
          checked={interfaceSettings.killActivityNotifications}
          setChecked={checked => updateSettings({ killActivityNotifications: checked })}
        />
        <PrettySwitchbox
          label="Play sound for map kill activity"
          checked={interfaceSettings.killActivitySounds}
          setChecked={checked => updateSettings({ killActivitySounds: checked })}
        />
      </div>

      <div className="mt-1 flex flex-col gap-2">
        <span className="text-xs text-stone-300">Scopes</span>
        <div className="grid grid-cols-3 gap-x-4 gap-y-2">
          {KILL_NOTIFICATION_SCOPE_OPTIONS.map(option => (
            <WdCheckbox
              key={option.value}
              size="xs"
              label={option.label}
              value={selectedScopes.includes(option.value)}
              classNameLabel="text-xs text-stone-400"
              onChange={event => handleToggleScope(option.value, event.checked ?? false)}
            />
          ))}
        </div>
      </div>

      <div className="grid grid-cols-[auto_1fr_auto] items-center">
        <label className="select-none text-xs text-stone-300">Toast lifetime:</label>
        <div className="mx-3 h-px border-b-2 border-dotted border-[#3f3f3f]" />
        <Dropdown
          className="text-sm"
          value={interfaceSettings.killActivityToastLifetimeSeconds ?? 0}
          options={KILL_NOTIFICATION_TOAST_LIFETIME_OPTIONS}
          onChange={event => updateSettings({ killActivityToastLifetimeSeconds: event.value })}
        />
      </div>

      <div className="mt-1 flex min-w-0 flex-col gap-1.5">
        <label className="text-xs text-stone-300">Avoid systems</label>
        <WdTagInput
          items={excludedSystems}
          getItemKey={systemId => systemId}
          renderItem={systemId => <SystemView systemId={systemId.toString()} showCustomName hideRegion compact />}
          onRemove={handleRemoveExcludedSystem}
          onOpen={handleOpenSystemDialog}
          placeholder="No systems excluded"
          addLabel="Select systems to exclude"
        />
        <span className="text-[0.65rem] text-stone-500">Kill notifications from selected systems will be ignored.</span>
      </div>

      <WdSystemSelectionDialog
        visible={systemDialogVisible}
        selectedSystemIds={draftExcludedSystems}
        title="Select systems to exclude"
        onAdd={() => setSystemSearchVisible(true)}
        onRemove={systemId => {
          setDraftExcludedSystems(current => current.filter(currentId => currentId !== systemId));
        }}
        onApply={handleApplyExcludedSystems}
        onHide={handleHideSystemDialog}
      />

      <AddSystemDialog
        visible={systemSearchVisible}
        setVisible={setSystemSearchVisible}
        title="Add system"
        excludedSystems={draftExcludedSystems}
        width={380}
        onSubmit={handleAddSystem}
      />
    </div>
  );
};
