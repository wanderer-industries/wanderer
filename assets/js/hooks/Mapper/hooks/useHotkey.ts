import { useEffect } from 'react';

export const useHotkey = (isMetaKey: boolean, hotkeys: string[], callback: () => void) => {
  useEffect(() => {
    const handleKeyDown = (event: KeyboardEvent) => {
      if ((!isMetaKey || event.ctrlKey || event.metaKey) && hotkeys.includes(event.key)) {
        if (event.target instanceof HTMLInputElement || event.target instanceof HTMLTextAreaElement) {
          return;
        }
        event.preventDefault();
        callback();
      }
    };

    window.addEventListener('keydown', handleKeyDown);

    return () => {
      window.removeEventListener('keydown', handleKeyDown);
    };
  }, [isMetaKey, hotkeys, callback]);
};
