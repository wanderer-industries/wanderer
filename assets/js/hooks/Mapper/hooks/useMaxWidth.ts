import { useState, useEffect, RefObject } from 'react';

const useMaxWidth = (ref: RefObject<HTMLElement>, maxWidth: number): boolean => {
  const [isExceeded, setIsExceeded] = useState(false);

  useEffect(() => {
    if (!ref.current) return;

    const observer = new ResizeObserver(entries => {
      for (const entry of entries) {
        if (entry.contentRect.width <= maxWidth) {
          setIsExceeded(true);
        } else {
          setIsExceeded(false);
        }
      }
    });

    observer.observe(ref.current);

    return () => {
      if (ref.current) observer.unobserve(ref.current);
    };
  }, [ref, maxWidth]);

  return isExceeded;
};

export default useMaxWidth;
