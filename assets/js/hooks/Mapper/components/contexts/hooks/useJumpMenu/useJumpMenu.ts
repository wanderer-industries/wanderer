import { isPossibleSpace } from '@/hooks/Mapper/components/map/helpers/isKnownSpace.ts';
import {
  JUMP_PLANNER_DESTINATION_SPACE,
  JUMP_PLANNER_FROM_SPACE,
} from '@/hooks/Mapper/components/mapRootContent/components/JumpPlanner/constants.ts';
import { MenuItem } from 'primereact/menuitem';
import { PrimeIcons } from 'primereact/api';
import { useCallback, useRef } from 'react';

export interface UseJumpMenuProps {
  onJumpFrom(systemId: string): void;
  onJumpTo(systemId: string): void;
}

export const useJumpMenu = ({ onJumpFrom, onJumpTo }: UseJumpMenuProps) => {
  const ref = useRef({ onJumpFrom, onJumpTo });
  ref.current = { onJumpFrom, onJumpTo };

  return useCallback((systemId: string, systemClass: number): MenuItem[] => {
    if (!isPossibleSpace(JUMP_PLANNER_FROM_SPACE, systemClass)) {
      return [];
    }

    const jumpFrom: MenuItem = {
      label: 'Jump From',
      icon: PrimeIcons.SIGN_OUT,
      command: () => ref.current.onJumpFrom(systemId),
    };

    if (!isPossibleSpace(JUMP_PLANNER_DESTINATION_SPACE, systemClass)) {
      return [jumpFrom];
    }

    return [
      jumpFrom,
      {
        label: 'Jump To',
        icon: PrimeIcons.SIGN_IN,
        command: () => ref.current.onJumpTo(systemId),
      },
    ];
  }, []);
};
