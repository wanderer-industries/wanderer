import { useRef } from 'react';
import {
  InfoDrawer,
  LayoutEventBlocker,
  SystemView,
  TooltipPosition,
  WdCheckbox,
  WdImgButton,
} from '@/hooks/Mapper/components/ui-kit';
import { PrimeIcons } from 'primereact/api';
import { CheckboxChangeEvent } from 'primereact/checkbox';
import { WdTooltipWrapper } from '@/hooks/Mapper/components/ui-kit/WdTooltipWrapper';
import useMaxWidth from '@/hooks/Mapper/hooks/useMaxWidth.ts';
import { COMPACT_MAX_WIDTH } from '@/hooks/Mapper/components/mapInterface/widgets/SystemSignatures/constants.ts';
import { useMapRootState } from '@/hooks/Mapper/mapRootProvider';

export type HeaderProps = {
  sigCount: number;
  lazyDeleteValue: boolean;
  onLazyDeleteChange: (checked: boolean) => void;
  pendingCount: number;
  undoCountdown?: number;
  onUndoClick: () => void;
  onSettingsClick: () => void;
};

export const SystemSignaturesHeader = ({
  sigCount,
  lazyDeleteValue,
  onLazyDeleteChange,
  pendingCount,
  undoCountdown,
  onUndoClick,
  onSettingsClick,
}: HeaderProps) => {
  const {
    data: { selectedSystems },
  } = useMapRootState();

  const [systemId] = selectedSystems;
  const isNotSelectedSystem = selectedSystems.length !== 1;

  const containerRef = useRef<HTMLDivElement>(null);
  const isCompact = useMaxWidth(containerRef, COMPACT_MAX_WIDTH);

  return (
    <div ref={containerRef} className="w-full">
      <div className="flex justify-between items-center text-xs w-full h-full">
        <div className="flex justify-between items-center gap-1">
          {!isCompact && (
            <div className="flex whitespace-nowrap text-ellipsis overflow-hidden text-stone-400">
              {sigCount ? `[${sigCount}] ` : ''}Signatures {isNotSelectedSystem ? '' : 'in'}
            </div>
          )}
          {!isNotSelectedSystem && <SystemView systemId={systemId} className="select-none text-center" hideRegion />}
        </div>

        <LayoutEventBlocker className="flex gap-2.5">
          <WdTooltipWrapper content="Enable Lazy delete">
            <WdCheckbox
              size="xs"
              labelSide="left"
              label={isCompact ? '' : 'Lazy delete'}
              value={lazyDeleteValue}
              classNameLabel="text-stone-400 hover:text-stone-200 transition duration-300 whitespace-nowrap text-ellipsis overflow-hidden"
              onChange={(event: CheckboxChangeEvent) => onLazyDeleteChange(!!event.checked)}
            />
          </WdTooltipWrapper>

          {pendingCount > 0 && (
            <WdImgButton
              className={PrimeIcons.UNDO}
              style={{ color: 'red' }}
              tooltip={{
                content: `Undo pending deletions (${pendingCount})${undoCountdown && undoCountdown > 0 ? ` — ${undoCountdown}s left` : ''}`,
              }}
              onClick={onUndoClick}
            />
          )}

          <WdImgButton
            className={PrimeIcons.QUESTION_CIRCLE}
            tooltip={{
              position: TooltipPosition.left,
              content: (
                <div className="flex flex-col gap-1">
                  <InfoDrawer title={<b className="text-slate-50">How to add/update signature?</b>}>
                    In game you need to select one or more signatures <br /> in the list in{' '}
                    <b className="text-sky-500">Probe scanner</b>. <br /> Use next hotkeys:
                    <br />
                    <b className="text-sky-500">Shift + LMB</b> or <b className="text-sky-500">Ctrl + LMB</b>
                    <br /> or <b className="text-sky-500">Ctrl + A</b> for select all
                    <br /> and then use <b className="text-sky-500">Ctrl + C</b>, after you need to go <br />
                    here, select Solar system and paste it with <b className="text-sky-500">Ctrl + V</b>
                  </InfoDrawer>
                  <InfoDrawer title={<b className="text-slate-50">How to select?</b>}>
                    For selecting any signature, click on it <br /> with hotkeys{' '}
                    <b className="text-sky-500">Shift + LMB</b> or <b className="text-sky-500">Ctrl + LMB</b>
                  </InfoDrawer>
                  <InfoDrawer title={<b className="text-slate-50">How to delete?</b>}>
                    To delete any signature, first select it <br /> and then press <b className="text-sky-500">Del</b>
                  </InfoDrawer>
                </div>
              ),
            }}
          />

          <WdImgButton className={PrimeIcons.SLIDERS_H} onClick={onSettingsClick} />
        </LayoutEventBlocker>
      </div>
    </div>
  );
};
