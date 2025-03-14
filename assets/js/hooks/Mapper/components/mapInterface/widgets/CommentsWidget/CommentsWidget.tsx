import { Widget } from '@/hooks/Mapper/components/mapInterface/components';
import { Comments } from '@/hooks/Mapper/components/mapInterface/components/Comments';
import { SystemView } from '@/hooks/Mapper/components/ui-kit';
import { useRef } from 'react';
import useMaxWidth from '@/hooks/Mapper/hooks/useMaxWidth.ts';
import { COMPACT_MAX_WIDTH } from '@/hooks/Mapper/components/mapInterface/widgets/SystemSignatures/constants.ts';
import { useMapRootState } from '@/hooks/Mapper/mapRootProvider';
import clsx from 'clsx';
import { CommentsEditor } from '@/hooks/Mapper/components/mapInterface/components/CommentsEditor';

export const CommentsWidgetContent = () => {
  const {
    data: { selectedSystems },
  } = useMapRootState();

  const isNotSelectedSystem = selectedSystems.length !== 1;

  if (isNotSelectedSystem) {
    return (
      <div className="w-full h-full flex justify-center items-center select-none text-stone-400/80 text-sm">
        System is not selected
      </div>
    );
  }

  return (
    <div className={clsx('h-full grid grid-rows-[1fr_auto] gap-1 px-[4px]')}>
      <Comments />
      <CommentsEditor />
    </div>
  );
};

export const CommentsWidget = () => {
  const containerRef = useRef<HTMLDivElement>(null);
  const isCompact = useMaxWidth(containerRef, COMPACT_MAX_WIDTH);

  const {
    data: { selectedSystems },
  } = useMapRootState();
  const [systemId] = selectedSystems;
  const isNotSelectedSystem = selectedSystems.length !== 1;

  return (
    <Widget
      label={
        <div ref={containerRef} className="flex items-center gap-1 text-xs w-full">
          {!isCompact && (
            <div className="flex whitespace-nowrap text-ellipsis overflow-hidden text-stone-400">
              Comments {isNotSelectedSystem ? '' : 'in'}
            </div>
          )}
          {!isNotSelectedSystem && <SystemView systemId={systemId} className="select-none text-center" hideRegion />}
        </div>
      }
    >
      <CommentsWidgetContent />
    </Widget>
  );
};
