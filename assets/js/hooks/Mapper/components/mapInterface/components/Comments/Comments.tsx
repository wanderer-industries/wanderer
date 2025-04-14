import { MarkdownComment } from '@/hooks/Mapper/components/mapInterface/components/Comments/components';
import { useEffect, useRef, useState } from 'react';
import { CommentType } from '@/hooks/Mapper/types';
import { useMapRootState } from '@/hooks/Mapper/mapRootProvider';

export interface CommentsProps {}

// eslint-disable-next-line no-empty-pattern
export const Comments = ({}: CommentsProps) => {
  const [commentsList, setCommentsList] = useState<CommentType[]>([]);

  const {
    data: { selectedSystems },
    comments: { loadComments, comments, lastUpdateKey },
  } = useMapRootState();

  const [systemId] = selectedSystems;

  const ref = useRef({ loadComments, systemId });
  ref.current = { loadComments, systemId };

  useEffect(() => {
    const commentsBySystem = comments.get(systemId);
    if (!commentsBySystem) {
      return;
    }

    const els = [...commentsBySystem.comments].sort((a, b) => +new Date(b.updated_at) - +new Date(a.updated_at));

    setCommentsList(els);
  }, [systemId, lastUpdateKey, comments]);

  useEffect(() => {
    ref.current.loadComments(systemId);
  }, [systemId]);

  if (commentsList.length === 0) {
    return (
      <div className="w-full h-full flex justify-center items-center select-none text-stone-400/80 text-sm">
        Not comments found here
      </div>
    );
  }

  return (
    <div className="flex flex-col gap-1 whitespace-nowrap overflow-auto text-ellipsis custom-scrollbar">
      {commentsList.map(({ id, text, updated_at, characterEveId }) => (
        <MarkdownComment key={id} text={text} time={updated_at} characterEveId={characterEveId} id={id} />
      ))}
    </div>
  );
};
