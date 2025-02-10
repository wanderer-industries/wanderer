import React, { useMemo, useState } from 'react';
import { useMapRootState } from '@/hooks/Mapper/mapRootProvider';
import { Widget } from '@/hooks/Mapper/components/mapInterface/components';
import { SystemKillsContent } from './SystemKillsContent/SystemKillsContent';
import { KillsHeader } from './components/SystemKillsHeader';
import { useKillsWidgetSettings } from './hooks/useKillsWidgetSettings';
import { useSystemKills } from './hooks/useSystemKills';
import { KillsSettingsDialog } from './components/SystemKillsSettingsDialog';
import { isWormholeSpace } from '@/hooks/Mapper/components/map/helpers/isWormholeSpace';

export const SystemKills: React.FC = React.memo(() => {
  const {
    data: { selectedSystems, systems, isSubscriptionActive },
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

  const systemBySolarSystemId = useMemo(() => {
    const map: Record<number, any> = {};
    systems.forEach(sys => {
      if (sys.system_static_info?.solar_system_id != null) {
        map[sys.system_static_info.solar_system_id] = sys;
      }
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

  const filteredKills = useMemo(() => {
    if (!settings.whOnly || !visible) return kills;
    return kills.filter(kill => {
      const system = systemBySolarSystemId[kill.solar_system_id];
      if (!system) {
        console.warn(`System with id ${kill.solar_system_id} not found.`);
        return false;
      }
      return isWormholeSpace(system.system_static_info.system_class);
    });
  }, [kills, settings.whOnly, systemBySolarSystemId, visible]);

  return (
    <div className="h-full flex flex-col min-h-0">
      <div className="flex flex-col flex-1 min-h-0">
        <Widget label={<KillsHeader systemId={systemId} onOpenSettings={() => setSettingsDialogVisible(true)} />}>
          {!isSubscriptionActive ? (
            <div className="w-full h-full flex items-center justify-center">
              <span className="select-none text-center text-stone-400/80 text-sm">
                Kills available with &#39;Active&#39; map subscription only (contact map administrators)
              </span>
            </div>
          ) : isNothingSelected ? (
            <div className="w-full h-full flex items-center justify-center">
              <span className="select-none text-center text-stone-400/80 text-sm">
                No system selected (or toggle “Show all systems”)
              </span>
            </div>
          ) : showLoading ? (
            <div className="w-full h-full flex items-center justify-center">
              <span className="select-none text-center text-stone-400/80 text-sm">Loading Kills...</span>
            </div>
          ) : error ? (
            <div className="w-full h-full flex items-center justify-center">
              <span className="select-none text-center text-red-400 text-sm">{error}</span>
            </div>
          ) : !filteredKills || filteredKills.length === 0 ? (
            <div className="w-full h-full flex items-center justify-center">
              <span className="select-none text-center text-stone-400/80 text-sm">No kills found</span>
            </div>
          ) : (
            <div className="w-full h-full" style={{ height: '100%' }}>
              <SystemKillsContent
                key={settings.compact ? 'compact' : 'normal'}
                kills={filteredKills}
                systemNameMap={systemNameMap}
                compact={settings.compact}
                onlyOneSystem={!visible}
                timeRange={settings.timeRange}
              />
            </div>
          )}
        </Widget>
      </div>

      <KillsSettingsDialog visible={settingsDialogVisible} setVisible={setSettingsDialogVisible} />
    </div>
  );
});

SystemKills.displayName = 'SystemKills';
