import { TooltipPosition, WdImageSize, WdImgButton } from '@/hooks/Mapper/components/ui-kit';
import clsx from 'clsx';
import { PrimeIcons } from 'primereact/api';
import { MarkdownEditor } from '@/hooks/Mapper/components/mapInterface/components/MarkdownEditor';
import { useHotkey } from '@/hooks/Mapper/hooks';
import { useCallback, useRef, useState } from 'react';
import { OutCommand } from '@/hooks/Mapper/types';
import { useMapRootState } from '@/hooks/Mapper/mapRootProvider';

export interface CommentsEditorProps {}

// eslint-disable-next-line no-empty-pattern
export const CommentsEditor = ({}: CommentsEditorProps) => {
  const [textVal, setTextVal] = useState('');

  const {
    data: { selectedSystems },
    outCommand,
  } = useMapRootState();

  const [systemId] = selectedSystems;

  const ref = useRef({ outCommand, systemId, textVal });
  ref.current = { outCommand, systemId, textVal };

  const handleFinishEdit = useCallback(async () => {
    if (ref.current.textVal === '') {
      return;
    }

    await ref.current.outCommand({
      type: OutCommand.addSystemComment,
      data: {
        solarSystemId: ref.current.systemId,
        value: ref.current.textVal,
      },
    });
    setTextVal('');
  }, []);

  const handleClick = async () => {
    await handleFinishEdit();
  };

  useHotkey(true, ['Enter'], async () => {
    await handleFinishEdit();
  });

  return (
    <MarkdownEditor
      value={textVal}
      onChange={setTextVal}
      overlayContent={
        <div className="w-full h-full flex justify-end items-end pointer-events-none pb-[1px] pr-[8px]">
          <WdImgButton
            disabled={textVal.length === 0}
            tooltip={{
              position: TooltipPosition.bottom,
              content: (
                <span>
                  Also you may use <span className="text-cyan-400">Meta + Enter</span> hotkey.
                </span>
              ),
            }}
            textSize={WdImageSize.large}
            className={clsx(PrimeIcons.SEND, 'text-[14px]')}
            onClick={handleClick}
          />
        </div>
      }
    />
  );
};
