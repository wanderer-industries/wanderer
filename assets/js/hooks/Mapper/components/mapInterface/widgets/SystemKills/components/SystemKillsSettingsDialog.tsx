import React, { useCallback, useEffect, useRef, useState } from 'react';
import { Dialog } from 'primereact/dialog';
import { Button } from 'primereact/button';
import { WdImgButton } from '@/hooks/Mapper/components/ui-kit';
import { PrimeIcons } from 'primereact/api';
import { useKillsWidgetSettings } from '../hooks/useKillsWidgetSettings';
import {
  AddSystemDialog,
  SearchOnSubmitCallback,
} from '@/hooks/Mapper/components/mapInterface/components/AddSystemDialog';
import { SystemView, TooltipPosition } from '@/hooks/Mapper/components/ui-kit';

interface KillsSettingsDialogProps {
  visible: boolean;
  setVisible: (visible: boolean) => void;
}

export const KillsSettingsDialog: React.FC<KillsSettingsDialogProps> = ({ visible, setVisible }) => {
  const [globalSettings, setGlobalSettings] = useKillsWidgetSettings();
  const localRef = useRef({
    showAll: globalSettings.showAll,
    whOnly: globalSettings.whOnly,
    excludedSystems: globalSettings.excludedSystems || [],
    timeRange: globalSettings.timeRange,
  });

  const [, forceRender] = useState(0);
  const [addSystemDialogVisible, setAddSystemDialogVisible] = useState(false);

  useEffect(() => {
    if (visible) {
      localRef.current = {
        showAll: globalSettings.showAll,
        whOnly: globalSettings.whOnly,
        excludedSystems: globalSettings.excludedSystems || [],
        timeRange: globalSettings.timeRange,
      };
      forceRender(n => n + 1);
    }
  }, [visible, globalSettings]);

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
    setGlobalSettings(prev => ({
      ...prev,
      ...localRef.current,
    }));
    setVisible(false);
  }, [setGlobalSettings, setVisible]);

  const handleHide = useCallback(() => {
    setVisible(false);
  }, [setVisible]);

  const localData = localRef.current;
  const excluded = localData.excludedSystems || [];
  const timeRangeOptions = [4, 12, 24];

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
          <Button onClick={handleApply} label="Apply" outlined size="small" />
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
