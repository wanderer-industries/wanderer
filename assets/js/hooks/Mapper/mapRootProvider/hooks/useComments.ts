import { useCallback, useRef, useState } from 'react';
import { CommentSystem, CommentType, OutCommand, OutCommandHandler, UseCommentsData } from '@/hooks/Mapper/types';

interface UseCommentsProps {
  outCommand: OutCommandHandler;
}

export const useComments = ({ outCommand }: UseCommentsProps): UseCommentsData => {
  const [lastUpdateKey, setLastUpdateKey] = useState(0);

  const commentBySystemsRef = useRef<Map<string, CommentSystem>>(new Map());

  const ref = useRef({ outCommand });
  ref.current = { outCommand };

  const loadComments = useCallback(async (systemId: string) => {
    let cSystem = commentBySystemsRef.current.get(systemId);
    if (cSystem?.loading || cSystem?.loaded) {
      return;
    }

    if (!cSystem) {
      cSystem = {
        loading: false,
        loaded: false,
        comments: [],
      };
    }

    cSystem.loading = true;

    const result: { comments: CommentType[] } = await ref.current.outCommand({
      type: OutCommand.getSystemComments,
      data: {
        solarSystemId: systemId,
      },
    });

    cSystem.loaded = true;
    cSystem.loading = false;
    cSystem.comments = [...cSystem.comments, ...result.comments];

    commentBySystemsRef.current.set(systemId, cSystem);

    setLastUpdateKey(x => x + 1);
  }, []);

  const addComment = useCallback((systemId: string, comment: CommentType) => {
    const cSystem = commentBySystemsRef.current.get(systemId);
    if (cSystem) {
      cSystem.comments.push(comment);
      setLastUpdateKey(x => x + 1);
      return;
    }

    commentBySystemsRef.current.set(systemId, {
      loading: false,
      loaded: false,
      comments: [comment],
    });
    setLastUpdateKey(x => x + 1);
  }, []);

  const removeComment = useCallback((systemId: string, commentId: string) => {
    const cSystem = commentBySystemsRef.current.get(systemId);
    if (!cSystem) {
      return;
    }

    const index = cSystem.comments.findIndex(x => x.id === commentId);

    if (index === -1) {
      return;
    }

    cSystem.comments = [...cSystem.comments.slice(0, index), ...cSystem.comments.splice(index + 1)];
    setLastUpdateKey(x => x + 1);
  }, []);

  return { loadComments, comments: commentBySystemsRef.current, lastUpdateKey, addComment, removeComment };
};
