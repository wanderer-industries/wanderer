import React, { useCallback, useEffect, useRef, useState } from 'react';
import { Dialog } from 'primereact/dialog';
import { SystemView, TooltipPosition, WdButton, WdImgButton } from '@/hooks/Mapper/components/ui-kit';
import { PrimeIcons } from 'primereact/api';
import {
  AddSystemDialog,
  SearchOnSubmitCallback,
} from '@/hooks/Mapper/components/mapInterface/components/AddSystemDialog';
import { useMapRootState } from '@/hooks/Mapper/mapRootProvider';

interface KillsSettingsDialogProps {
  visible: boolean;
  setVisible: (visible: boolean) => void;
}

export const KillsSettingsDialog: React.FC<KillsSettingsDialogProps> = ({ visible, setVisible }) => {
  const {
    storedSettings: { settingsKills, settingsKillsUpdate },
  } = useMapRootState();

  const localRef = useRef({
    showAll: settingsKills.showAll,
    whOnly: settingsKills.whOnly,
    excludedSystems: settingsKills.excludedSystems || [],
    timeRange: settingsKills.timeRange,
  });

  const [, forceRender] = useState(0);
  const [addSystemDialogVisible, setAddSystemDialogVisible] = useState(false);

  useEffect(() => {
    if (visible) {
      localRef.current = {
        showAll: settingsKills.showAll,
        whOnly: settingsKills.whOnly,
        excludedSystems: settingsKills.excludedSystems || [],
        timeRange: settingsKills.timeRange,
      };
      forceRender(n => n + 1);
    }
  }, [visible, settingsKills]);

  const handleWHChange = useCallback((checked: boolean) => {
    localRef.current = {
      ...localRef.current,
      whOnly: checked,
    };
    forceRender(n => n + 1);
  }, []);

  const handleTimeRangeChange = useCallback((newTimeRange: number) => {
    localRef.current = {
      ...localRef.current,
      timeRange: newTimeRange,
    };
    forceRender(n => n + 1);
  }, []);

  const handleRemoveSystem = useCallback((sysId: number) => {
    localRef.current = {
      ...localRef.current,
      excludedSystems: localRef.current.excludedSystems.filter(id => id !== sysId),
    };
    forceRender(n => n + 1);
  }, []);

  const handleAddSystemSubmit: SearchOnSubmitCallback = useCallback(item => {
    if (localRef.current.excludedSystems.includes(item.value)) {
      return;
    }
    localRef.current = {
      ...localRef.current,
      excludedSystems: [...localRef.current.excludedSystems, item.value],
    };
    forceRender(n => n + 1);
  }, []);

  const handleApply = useCallback(() => {
    settingsKillsUpdate(prev => ({
      ...prev,
      ...localRef.current,
    }));
    setVisible(false);
  }, [settingsKillsUpdate, setVisible]);

  const handleHide = useCallback(() => {
    setVisible(false);
  }, [setVisible]);

  const localData = localRef.current;
  const excluded = localData.excludedSystems || [];
  const timeRangeOptions = [4, 12, 24];

  // Ensure timeRange is one of the valid options
  useEffect(() => {
    if (visible && !timeRangeOptions.includes(localData.timeRange)) {
      // If current timeRange is not in options, set it to the default (4 hours)
      handleTimeRangeChange(4);
    }
  }, [visible, localData.timeRange, handleTimeRangeChange]);

  return (
    <Dialog header="Kills Settings" visible={visible} style={{ width: '440px' }} draggable={false} onHide={handleHide}>
      <div className="flex flex-col gap-3 p-2.5">
        <div className="flex items-center gap-2">
          <input
            type="checkbox"
            id="kills-wormhole-only-mode"
            checked={localData.whOnly}
            onChange={e => handleWHChange(e.target.checked)}
          />
          <label htmlFor="kills-wormhole-only-mode" className="cursor-pointer">
            Only show wormhole kills
          </label>
        </div>

        <div className="flex flex-col gap-1">
          <span className="text-sm">Time Range:</span>
          <div className="flex flex-wrap gap-2">
            {timeRangeOptions.map(option => (
              <label key={option} className="cursor-pointer flex items-center gap-1">
                <input
                  type="radio"
                  name="timeRange"
                  value={option}
                  checked={localData.timeRange === option}
                  onChange={() => handleTimeRangeChange(option)}
                />
                <span className="text-sm">{option} Hours</span>
              </label>
            ))}
          </div>
        </div>

        {/* Excluded Systems */}
        <div className="flex flex-col gap-1">
          <div className="flex items-center justify-between">
            <label className="text-sm text-stone-400">Excluded Systems</label>
            <WdImgButton
              className={PrimeIcons.PLUS_CIRCLE}
              onClick={() => setAddSystemDialogVisible(true)}
              tooltip={{ content: 'Add system to excluded list' }}
            />
          </div>
          {excluded.length === 0 && <div className="text-stone-500 text-xs italic">No systems excluded.</div>}
          {excluded.map(sysId => (
            <div key={sysId} className="flex items-center justify-between border-b border-stone-600 py-1 px-1 text-xs">
              <SystemView systemId={sysId.toString()} hideRegion />
              <WdImgButton
                className={PrimeIcons.TRASH}
                onClick={() => handleRemoveSystem(sysId)}
                tooltip={{ content: 'Remove from excluded', position: TooltipPosition.top }}
              />
            </div>
          ))}
        </div>

        <div className="flex gap-2 justify-end mt-4">
          <WdButton onClick={handleApply} label="Apply" outlined size="small" />
        </div>
      </div>

      <AddSystemDialog
        title="Add system to kills exclude list"
        visible={addSystemDialogVisible}
        setVisible={() => setAddSystemDialogVisible(false)}
        onSubmit={handleAddSystemSubmit}
        excludedSystems={excluded}
      />
    </Dialog>
  );
};
