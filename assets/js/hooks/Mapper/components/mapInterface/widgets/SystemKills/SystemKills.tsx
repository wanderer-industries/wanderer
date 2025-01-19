import React, { useMemo } from 'react';
import { useMapRootState } from '@/hooks/Mapper/mapRootProvider';
import { Widget } from '@/hooks/Mapper/components/mapInterface/components';
import { useSystemKills } from './hooks/useSystemKills';
import { SystemKillsContent } from './SystemKillsContent/SystemKillsContent';
import { KillsHeader } from './components/SystemKillsHeader';
import { useKillsWidgetSettings } from './hooks/useKillsWidgetSettings';

export const SystemKills: React.FC = () => {
  const {
    data: { selectedSystems, systems },
    outCommand,
  } = useMapRootState();

  const [systemId] = selectedSystems || [];

  const systemNameMap = useMemo(() => {
    const map: Record<string, string> = {};
    systems.forEach(sys => {
      map[sys.id] = sys.temporary_name || sys.name || '???';
    });
    return map;
  }, [systems]);

  const [settings] = useKillsWidgetSettings();
  const visible = settings.showAllVisible;

  const { kills, isLoading, error } = useSystemKills({
    systemId,
    outCommand,
    showAllVisible: visible,
  });

  const isNothingSelected = !systemId && !visible;

  const showLoading = isLoading && kills.length === 0;

  return (
    <div className="h-full flex flex-col">
      <div className="flex flex-col flex-1">
        <Widget label={<KillsHeader systemId={systemId} />}>
          {isNothingSelected && (
            <div className="w-full h-full flex justify-center items-center select-none text-center text-stone-400/80 text-sm">
              No system selected (or toggle “Show all visible”)
            </div>
          )}

          {!isNothingSelected && showLoading && (
            <div className="w-full h-full flex justify-center items-center text-center">
              <span className="text-stone-200 text-sm">Loading kills...</span>
            </div>
          )}

          {!isNothingSelected && !showLoading && error && (
            <div className="w-full h-full flex justify-center items-center text-red-400 text-sm">{error}</div>
          )}

          {!isNothingSelected && !showLoading && !error && (
            <div className="flex-1 overflow-y-auto" style={{ maxHeight: '600px' }}>
              <SystemKillsContent
                // Force re-mount on compact toggle:
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
    </div>
  );
};
