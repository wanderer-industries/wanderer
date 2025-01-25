import React, { useCallback, ClipboardEvent, useRef } from 'react';
import { useMapRootState } from '@/hooks/Mapper/mapRootProvider';
import useMaxWidth from '@/hooks/Mapper/hooks/useMaxWidth';
import {
  LayoutEventBlocker,
  WdImgButton,
  TooltipPosition,
  InfoDrawer,
  SystemView,
} from '@/hooks/Mapper/components/ui-kit';
import { PrimeIcons } from 'primereact/api';
import { Widget } from '@/hooks/Mapper/components/mapInterface/components';

import { SystemStructuresContent } from './SystemStructuresContent/SystemStructuresContent';
import { useSystemStructures } from './hooks/useSystemStructures';
import { processSnippetText } from './helpers';

export const SystemStructures: React.FC = () => {
  const {
    data: { selectedSystems },
    outCommand,
  } = useMapRootState();
  const [systemId] = selectedSystems;
  const isNotSelectedSystem = selectedSystems.length !== 1;

  const { structures, handleUpdateStructures } = useSystemStructures({ systemId, outCommand });

  const labelRef = useRef<HTMLDivElement>(null);
  const isCompact = useMaxWidth(labelRef, 260);

  const processClipboard = useCallback(
    (text: string) => {
      const updated = processSnippetText(text, structures);
      handleUpdateStructures(updated);
    },
    [structures, handleUpdateStructures],
  );

  const handlePaste = useCallback(
    (e: ClipboardEvent<HTMLDivElement>) => {
      e.preventDefault();
      processClipboard(e.clipboardData.getData('text'));
    },
    [processClipboard],
  );

  const handlePasteTimer = useCallback(async () => {
    try {
      const text = await navigator.clipboard.readText();
      processClipboard(text);
    } catch (err) {
      console.error('Clipboard read error:', err);
    }
  }, [processClipboard]);

  function renderWidgetLabel() {
    return (
      <div className="flex justify-between items-center text-xs w-full h-full" ref={labelRef}>
        <div className="flex justify-between items-center gap-1">
          {!isCompact && (
            <div className="flex whitespace-nowrap text-ellipsis overflow-hidden text-stone-400">
              Structures
              {!isNotSelectedSystem && ' in'}
            </div>
          )}
          {!isNotSelectedSystem && <SystemView systemId={systemId} className="select-none text-center" hideRegion />}
        </div>

        <LayoutEventBlocker className="flex gap-2.5">
          <WdImgButton
            className={`${PrimeIcons.CLOCK} text-sky-400 hover:text-sky-200 transition duration-300`}
            onClick={handlePasteTimer}
            tooltip={{
              position: TooltipPosition.left,
              // @ts-ignore
              content: 'Add Structures/Timer',
            }}
          />
          <WdImgButton
            className={PrimeIcons.QUESTION_CIRCLE}
            tooltip={{
              position: TooltipPosition.left,
              // @ts-ignore
              content: (
                <div className="flex flex-col gap-1">
                  <InfoDrawer title={<b className="text-slate-50">How to add/update structures?</b>}>
                    In game, select one or more structures in D-Scan and then
                    <br />
                    use the blue add structure data button
                  </InfoDrawer>
                  <InfoDrawer title={<b className="text-slate-50">How to add a timer?</b>}>
                    In game, select a structure with an active timer, right click to copy, and then
                    <span className="text-blue-500"> blue </span>
                    use the blue add structure data button
                  </InfoDrawer>
                </div>
              ),
            }}
          />
        </LayoutEventBlocker>
      </div>
    );
  }

  return (
    <div tabIndex={0} onPaste={handlePaste} className="h-full flex flex-col" style={{ outline: 'none' }}>
      <Widget label={renderWidgetLabel()}>
        {isNotSelectedSystem ? (
          <div className="w-full h-full flex justify-center items-center select-none text-center text-stone-400/80 text-sm">
            System is not selected
          </div>
        ) : (
          <SystemStructuresContent structures={structures} onUpdateStructures={handleUpdateStructures} />
        )}
      </Widget>
    </div>
  );
};
