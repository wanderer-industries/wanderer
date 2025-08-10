import classes from './MarkdownComment.module.scss';
import clsx from 'clsx';
import {
  InfoDrawer,
  MarkdownTextViewer,
  TimeAgo,
  TooltipPosition,
  WdImgButton,
} from '@/hooks/Mapper/components/ui-kit';
import { useGetCacheCharacter } from '@/hooks/Mapper/mapRootProvider/hooks/api';
import { useCallback, useRef, useState } from 'react';
import { WdTransition } from '@/hooks/Mapper/components/ui-kit/WdTransition/WdTransition.tsx';
import { PrimeIcons } from 'primereact/api';
import { ConfirmPopup } from 'primereact/confirmpopup';
import { useMapRootState } from '@/hooks/Mapper/mapRootProvider';
import { OutCommand } from '@/hooks/Mapper/types';
import { useConfirmPopup } from '@/hooks/Mapper/hooks';

const TOOLTIP_PROPS = { content: 'Remove comment', position: TooltipPosition.top };

export interface MarkdownCommentProps {
  text: string;
  time: string;
  characterEveId: string;
  id: string;
}

export const MarkdownComment = ({ text, time, characterEveId, id }: MarkdownCommentProps) => {
  const char = useGetCacheCharacter(characterEveId);
  const [hovered, setHovered] = useState(false);

  const { cfShow, cfHide, cfVisible, cfRef } = useConfirmPopup();

  const { outCommand } = useMapRootState();
  const ref = useRef({ outCommand, id });
  ref.current = { outCommand, id };

  const handleDelete = useCallback(async () => {
    await ref.current.outCommand({
      type: OutCommand.deleteSystemComment,
      data: ref.current.id,
    });
  }, []);

  const handleMouseEnter = useCallback(() => setHovered(true), []);
  const handleMouseLeave = useCallback(() => setHovered(false), []);

  return (
    <>
      <InfoDrawer
        labelClassName="mb-[3px]"
        className={clsx(classes.MarkdownCommentRoot, 'p-1 bg-stone-700/20 ')}
        onMouseEnter={handleMouseEnter}
        onMouseLeave={handleMouseLeave}
        title={
          <div className="flex items-center justify-between">
            <div>
              <span className="text-stone-500">
                by <span className="text-orange-300/70">{char?.data?.name ?? ''}</span>
              </span>
            </div>

            <WdTransition active={hovered} timeout={100}>
              <div className="text-stone-500 max-h-[12px]">
                {!hovered && <TimeAgo timestamp={time} />}
                {hovered && (
                  // @ts-ignore
                  <div ref={cfRef}>
                    <WdImgButton
                      className={clsx(PrimeIcons.TRASH, 'hover:text-red-400')}
                      tooltip={TOOLTIP_PROPS}
                      onClick={cfShow}
                    />
                  </div>
                )}
              </div>
            </WdTransition>
          </div>
        }
      >
        <MarkdownTextViewer>{text}</MarkdownTextViewer>
      </InfoDrawer>

      <ConfirmPopup
        target={cfRef.current}
        visible={cfVisible}
        onHide={cfHide}
        message="Are you sure you want to delete?"
        icon="pi pi-exclamation-triangle"
        accept={handleDelete}
      />
    </>
  );
};
