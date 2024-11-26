import { useEffect } from 'react';

export const useHotkey = (isMetaKey: boolean, hotkeys: string[], callback: (e: KeyboardEvent) => void) => {
  useEffect(() => {
    const handleKeyDown = (event: KeyboardEvent) => {
      if ((!isMetaKey || event.ctrlKey || event.metaKey) && hotkeys.includes(event.key)) {
        if (event.target instanceof HTMLInputElement || event.target instanceof HTMLTextAreaElement) {
          return;
        }
        event.preventDefault();
        callback(event);
      }
    };

    window.addEventListener('keydown', handleKeyDown, { capture: true });

    return () => {
      window.removeEventListener('keydown', handleKeyDown, { capture: true });
    };
  }, [isMetaKey, hotkeys, callback]);
};
