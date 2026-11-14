import { useEffect } from 'react';

type HotkeyCallback = (event: KeyboardEvent) => boolean | void | Promise<boolean | void>;

export const useHotkey = (isMetaKey: boolean, hotkeys: string[], callback: HotkeyCallback) => {
  useEffect(() => {
    const handleKeyDown = (event: KeyboardEvent) => {
      const matchesHotkey = hotkeys.includes(event.key) || hotkeys.includes(event.code);

      if ((!isMetaKey || event.ctrlKey || event.metaKey) && matchesHotkey) {
        if (event.target instanceof HTMLInputElement || event.target instanceof HTMLTextAreaElement) {
          return;
        }

        const handled = callback(event);
        if (handled === false) {
          return;
        }

        event.preventDefault();
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
