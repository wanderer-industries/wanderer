import { useCallback } from 'react';
import { useToast } from '@/hooks/Mapper/ToastProvider';
import type { PageCharactersCommandReply, PageCharactersOutCommandHandler } from '../types';
import { PageCharactersOutCommand } from '../types';

export const useCharacterAuthorization = (
  outCommand: PageCharactersOutCommandHandler,
  setError: (error: string | null) => void,
) => {
  const { show: showToast } = useToast();

  return useCallback(
    async (trackWallet: boolean) => {
      const reply = await outCommand<PageCharactersCommandReply>({
        type: PageCharactersOutCommand.authorize,
        data: { track_wallet: trackWallet },
      });

      if (!reply.ok) {
        const message = reply.error ?? 'Unable to start EVE authorization.';
        setError(message);
        showToast({ severity: 'error', summary: 'Authorization failed', detail: message });
      }
    },
    [outCommand, setError, showToast],
  );
};
