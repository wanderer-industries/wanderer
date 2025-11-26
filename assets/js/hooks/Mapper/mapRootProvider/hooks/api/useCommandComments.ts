import { useMapRootState } from '@/hooks/Mapper/mapRootProvider';
import { CommandCommentAdd, CommandCommentRemoved } from '@/hooks/Mapper/types';
import { useCallback, useRef } from 'react';

export const useCommandComments = () => {
  const { comments } = useMapRootState();
  const ref = useRef(comments);
  ref.current = comments;

  const addComment = useCallback((data: CommandCommentAdd) => {
    ref.current.addComment(data.solarSystemId, data.comment);
  }, []);

  const removeComment = useCallback((data: CommandCommentRemoved) => {
    ref.current.removeComment(data.solarSystemId.toString(), data.commentId);
  }, []);

  return { addComment, removeComment };
};
