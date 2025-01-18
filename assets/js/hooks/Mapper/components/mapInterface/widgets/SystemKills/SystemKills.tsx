import React, { useState, useMemo, useCallback } from 'react';
import { useMapRootState } from '@/hooks/Mapper/mapRootProvider';
import { Widget } from '@/hooks/Mapper/components/mapInterface/components';
import { useSystemKills } from './hooks/useSystemKills';
import { SystemKillsContent } from './SystemKillsContent/SystemKillsContent';
import { KillsHeader } from './components/SystemKillsHeader';
import useLocalStorageState from 'use-local-storage-state';
import { KillWidgetSettingsType, KILL_WIDGET_DEFAULT } from './helpers';

export const SystemKills: React.FC = () => {
  const {
    data: { selectedSystems, systems },
    outCommand,
  } = useMapRootState();

  const [systemId] = selectedSystems || [];
  const [showAllVisible, setShowAllVisible] = useState(false);

  const [killSettings, setKillSettings] = useLocalStorageState<KillWidgetSettingsType>('window:kills:settings', {
    defaultValue: KILL_WIDGET_DEFAULT,
  });

  const systemNameMap = useMemo(() => {
    const map: Record<string, string> = {};
    systems.forEach(sys => {
      map[sys.id] = sys.temporary_name || sys.name || '???';
    });
    return map;
  }, [systems]);

  const { kills, isLoading, error } = useSystemKills({
    systemId,
    outCommand,
    showAllVisible,
  });

  const isNothingSelected = !systemId && !showAllVisible;

  const handleToggleShowAllVisible = useCallback(() => {
    setShowAllVisible(prev => !prev);
  }, []);

  const handleToggleCompact = useCallback(() => {
    setKillSettings(prev => ({ ...prev, compact: !prev.compact }));
  }, [setKillSettings]);

  return (
    <div className="h-full flex flex-col">
      <div className="flex flex-col flex-1">
        <Widget
          label={
            <KillsHeader
              systemId={systemId}
              showAllVisible={showAllVisible}
              onToggleShowAllVisible={handleToggleShowAllVisible}
              compact={killSettings.compact}
              onToggleCompact={handleToggleCompact}
            />
          }
        >
          {isNothingSelected && (
            <div className="w-full h-full flex justify-center items-center select-none text-center text-stone-400/80 text-sm">
              No system selected (or toggle “Show all visible”)
            </div>
          )}
          {!isNothingSelected && isLoading && (
            <div className="w-full h-full flex justify-center items-center text-center">
              <span className="text-stone-200 text-sm">Loading kills...</span>
            </div>
          )}
          {!isNothingSelected && !isLoading && error && (
            <div className="w-full h-full flex justify-center items-center text-red-400 text-sm">{error}</div>
          )}
          {!isNothingSelected && !isLoading && !error && (
            <div className="flex-1 overflow-y-auto">
              <SystemKillsContent kills={kills} systemNameMap={systemNameMap} compact={killSettings.compact} />
            </div>
          )}
        </Widget>
      </div>
    </div>
  );
};
