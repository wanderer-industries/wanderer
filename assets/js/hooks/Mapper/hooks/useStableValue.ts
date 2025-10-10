import { useRef } from 'react';
import fastDeepEuqal from 'fast-deep-equal';

export const useStableValue = <T>(value: T): T => {
  const ref = useRef(value);
  if (!fastDeepEuqal(ref.current, value)) ref.current = value;
  return ref.current;
};
