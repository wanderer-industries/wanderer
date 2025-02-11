import { useState, useLayoutEffect, RefObject } from 'react';

/**
 * useElementWidth
 *
 * A custom hook that accepts a ref to an HTML element and returns its current width.
 * It uses a ResizeObserver and window resize listener to update the width when necessary.
 *
 * @param ref - A RefObject pointing to an HTML element.
 * @returns The current width of the element.
 */
export function useElementWidth<T extends HTMLElement>(ref: RefObject<T>): number {
  const [width, setWidth] = useState<number>(0);

  useLayoutEffect(() => {
    const updateWidth = () => {
      if (ref.current) {
        const newWidth = ref.current.getBoundingClientRect().width;
        if (newWidth > 0) {
          setWidth(newWidth);
        }
      }
    };

    updateWidth(); // Initial measurement

    const observer = new ResizeObserver(() => {
      const id = setTimeout(updateWidth, 100);
      return () => clearTimeout(id);
    });

    if (ref.current) {
      observer.observe(ref.current);
    }
    window.addEventListener("resize", updateWidth);
    return () => {
      observer.disconnect();
      window.removeEventListener("resize", updateWidth);
    };
  }, [ref]);

  return width;
}
