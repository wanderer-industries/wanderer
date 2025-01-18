import React, { useState, useMemo, useCallback } from 'react';
import { useMapRootState } from '@/hooks/Mapper/mapRootProvider';
import { Widget } from '@/hooks/Mapper/components/mapInterface/components';
import { useSystemKills } from './hooks/useSystemKills';
import { SystemKillsContent } from './SystemKillsContent/SystemKillsContent';
import { KillsHeader } from './components/SystemKillsHeader';

export const SystemKills: React.FC = () => {
  const {
    data: { selectedSystems, systems },
    outCommand,
  } = useMapRootState();

  const [systemId] = selectedSystems || [];
  const [showAllVisible, setShowAllVisible] = useState(false);

  const visibleSystemIds = useMemo(() => systems.map(s => s.id), [systems]);

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

  const renderNoSystem = () => (
    <div className="w-full h-full flex justify-center items-center select-none text-center text-stone-400/80 text-sm">
      No system selected (or toggle “Show all visible”)
    </div>
  );

  const renderLoading = () => (
    <div className="w-full h-full flex justify-center items-center text-center">
      <span className="text-stone-200 text-sm">Loading kills...</span>
    </div>
  );

  const renderError = () => (
    <div className="w-full h-full flex justify-center items-center text-red-400 text-sm">{error}</div>
  );

  return (
    <div className="h-full flex flex-col">
      <Widget
        label={
          <KillsHeader
            systemId={systemId}
            showAllVisible={showAllVisible}
            onToggleShowAllVisible={handleToggleShowAllVisible}
          />
        }
      >
        {isNothingSelected && renderNoSystem()}
        {!isNothingSelected && isLoading && renderLoading()}
        {!isNothingSelected && !isLoading && error && renderError()}
        {!isNothingSelected && !isLoading && !error && (
          <SystemKillsContent kills={kills} systemNameMap={systemNameMap} />
        )}
      </Widget>
    </div>
  );
};
