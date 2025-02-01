import React, { useMemo, useState } from 'react';
import { useMapRootState } from '@/hooks/Mapper/mapRootProvider';
import { Widget } from '@/hooks/Mapper/components/mapInterface/components';
import { SystemKillsContent } from './SystemKillsContent/SystemKillsContent';
import { KillsHeader } from './components/SystemKillsHeader';
import { useKillsWidgetSettings } from './hooks/useKillsWidgetSettings';
import { useSystemKills } from './hooks/useSystemKills';
import { KillsSettingsDialog } from './components/SystemKillsSettingsDialog';

export const SystemKills: React.FC = () => {
  const {
    data: { selectedSystems, systems },
    outCommand,
  } = useMapRootState();

  const [systemId] = selectedSystems || [];

  const [settingsDialogVisible, setSettingsDialogVisible] = useState(false);

  const systemNameMap = useMemo(() => {
    const map: Record<string, string> = {};
    systems.forEach(sys => {
      map[sys.id] = sys.temporary_name || sys.name || '???';
    });
    return map;
  }, [systems]);

  const [settings] = useKillsWidgetSettings();
  const visible = settings.showAll;

  const { kills, isLoading, error } = useSystemKills({
    systemId,
    outCommand,
    showAllVisible: visible,
  });

  const isNothingSelected = !systemId && !visible;
  const showLoading = isLoading && kills.length === 0;

  return (
    <div className="h-full flex flex-col min-h-0">
      <div className="flex flex-col flex-1 min-h-0">
        <Widget label={<KillsHeader systemId={systemId} onOpenSettings={() => setSettingsDialogVisible(true)} />}>
          {isNothingSelected && (
            <div className="w-full h-full flex justify-center items-center select-none text-center text-stone-400/80 text-sm">
              No system selected (or toggle “Show all systems”)
            </div>
          )}

          {!isNothingSelected && showLoading && (
            <div className="w-full h-full flex justify-center items-center select-none text-center text-stone-400/80 text-sm">
              Loading Kills...
            </div>
          )}

          {!isNothingSelected && !showLoading && error && (
            <div className="w-full h-full flex justify-center items-center select-none text-center text-red-400 text-sm">
              {error}
            </div>
          )}

          {!isNothingSelected && !showLoading && !error && (!kills || kills.length === 0) && (
            <div className="w-full h-full flex justify-center items-center select-none text-center text-stone-400/80 text-sm">
              No kills found
            </div>
          )}

          {!isNothingSelected && !showLoading && !error && (
            <div className="flex-1 flex flex-col overflow-y-auto">
              <SystemKillsContent
                key={settings.compact ? 'compact' : 'normal'}
                kills={kills}
                systemNameMap={systemNameMap}
                compact={settings.compact}
                onlyOneSystem={!visible}
              />
            </div>
          )}
        </Widget>
      </div>

      <KillsSettingsDialog visible={settingsDialogVisible} setVisible={setSettingsDialogVisible} />
    </div>
  );
};
