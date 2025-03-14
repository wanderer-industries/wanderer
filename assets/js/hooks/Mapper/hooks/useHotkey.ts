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

    // TODO not sure that capture still needs
    window.addEventListener('keydown', handleKeyDown, { capture: false });

    return () => {
      // TODO not sure that capture still needs
      window.removeEventListener('keydown', handleKeyDown, { capture: false });
    };
  }, [isMetaKey, hotkeys, callback]);
};
