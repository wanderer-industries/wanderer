import { useCallback, useRef } from 'react';

export const useThrottle = (callback: any, limit: number) => {
  const lastCallRef = useRef(0);
  const throttledCallback = useCallback(() => {
    const now = Date.now();
    if (now - lastCallRef.current >= limit) {
      lastCallRef.current = now;
      callback();
    }
  }, [callback, limit]);
  return throttledCallback;
};
