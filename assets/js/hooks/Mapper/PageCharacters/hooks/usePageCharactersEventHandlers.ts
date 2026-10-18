import { useImperativeHandle } from 'react';
import type { ForwardedRef } from 'react';
import {
  PageCharactersCommand,
  type PageCharactersCommandData,
  type PageCharactersHandlers,
  type PageCharactersSnapshot,
} from '../types';

export const usePageCharactersEventHandlers = (
  ref: ForwardedRef<PageCharactersHandlers>,
  applySnapshot: (snapshot: PageCharactersSnapshot) => void,
) => {
  useImperativeHandle(
    ref,
    () => ({
      command<T extends PageCharactersCommand>(type: T, data: PageCharactersCommandData[T]) {
        switch (type) {
          case PageCharactersCommand.snapshot:
            applySnapshot(data as PageCharactersSnapshot);
            break;
          default:
            console.warn(`PageCharacters handlers: Unknown command: ${type}`, data);
        }
      },
    }),
    [applySnapshot],
  );
};
