import { useCallback, useEffect, useState } from 'react';
import { useToast } from '@/hooks/Mapper/ToastProvider';
import type { PageCharacter, PageCharactersCommandReply, PageCharactersOutCommandHandler } from '../types';
import { PageCharactersOutCommand } from '../types';

const DELETE_IN_PROGRESS_WARNING = 'A character is still being deleted.';

export const useCharacterDeletion = (
  characters: PageCharacter[],
  outCommand: PageCharactersOutCommandHandler,
  setError: (error: string | null) => void,
) => {
  const { show: showToast } = useToast();
  const [deletingCharacterId, setDeletingCharacterId] = useState<string | null>(null);
  const [deletingCharacterName, setDeletingCharacterName] = useState<string | null>(null);

  const clearPendingDeletion = useCallback(() => {
    setDeletingCharacterId(null);
    setDeletingCharacterName(null);
  }, []);

  useEffect(() => {
    if (!deletingCharacterId || !deletingCharacterName) {
      return;
    }

    const characterStillExists = characters.some(character => character.id === deletingCharacterId);
    if (characterStillExists) {
      return;
    }

    showToast({
      severity: 'success',
      summary: 'Character deleted',
      detail: `${deletingCharacterName} was successfully deleted.`,
    });
    clearPendingDeletion();
  }, [characters, clearPendingDeletion, deletingCharacterId, deletingCharacterName, showToast]);

  useEffect(() => {
    if (!deletingCharacterId) {
      return;
    }

    const warnBeforeLeaving = (event: BeforeUnloadEvent) => {
      event.preventDefault();
      event.returnValue = DELETE_IN_PROGRESS_WARNING;
      return DELETE_IN_PROGRESS_WARNING;
    };

    window.addEventListener('beforeunload', warnBeforeLeaving);
    return () => window.removeEventListener('beforeunload', warnBeforeLeaving);
  }, [deletingCharacterId]);

  const deleteCharacter = useCallback(
    async (characterId: string, characterName: string) => {
      setDeletingCharacterId(characterId);
      setDeletingCharacterName(characterName);

      try {
        const reply = await outCommand<PageCharactersCommandReply>({
          type: PageCharactersOutCommand.delete,
          data: { character_id: characterId },
        });

        if (!reply.ok) {
          const message = reply.error ?? 'Unable to delete character.';
          setError(message);
          showToast({ severity: 'error', summary: 'Delete failed', detail: message });
          clearPendingDeletion();
        }
      } catch {
        const message = 'Unable to delete character.';
        setError(message);
        showToast({ severity: 'error', summary: 'Delete failed', detail: message });
        clearPendingDeletion();
      }
    },
    [clearPendingDeletion, outCommand, setError, showToast],
  );

  return { deletingCharacterId, deleteCharacter };
};
