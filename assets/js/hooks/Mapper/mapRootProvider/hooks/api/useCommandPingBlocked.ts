import { useToast } from '@/hooks/Mapper/ToastProvider';
import { CommandPingBlocked } from '@/hooks/Mapper/types';
import { useCallback } from 'react';

export const useCommandPingBlocked = () => {
  const { show } = useToast();

  const pingBlocked = useCallback(
    ({ message }: CommandPingBlocked) => {
      show({
        severity: 'warn',
        summary: 'Cannot create ping',
        detail: message,
        life: 5000,
      });
    },
    [show],
  );

  return { pingBlocked };
};
