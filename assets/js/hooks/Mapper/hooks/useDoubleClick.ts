import { useCallback, useRef } from 'react';

export const useDoubleClick = (onDoubleClick: () => void, delay: number = 250) => {
  const ref = useRef({ clickCount: 0, firstClickTime: 0 });

  return useCallback(() => {
    ref.current.clickCount += 1;
    if (ref.current.clickCount === 1) {
      ref.current.firstClickTime = new Date().getTime();
      return;
    }

    const expired = ref.current.firstClickTime + delay;
    if (expired < new Date().getTime()) {
      ref.current.firstClickTime = new Date().getTime();
      ref.current.clickCount = 1;
      return;
    }

    ref.current.clickCount = 0;
    onDoubleClick();
  }, [delay, onDoubleClick]);
};
