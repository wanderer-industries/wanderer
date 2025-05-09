import { useEffect } from 'react';

type Settings = Record<string, unknown>;
export const useActualizeSettings = <T extends Settings>(defaultVals: T, vals: T, setVals: (newVals: T) => void) => {
  useEffect(() => {
    let foundNew = false;
    const newVals = Object.keys(defaultVals).reduce((acc, x) => {
      if (Object.keys(acc).includes(x)) {
        return acc;
      }

      foundNew = true;

      // @ts-ignore
      return { ...acc, [x]: defaultVals[x] };
    }, vals);

    if (foundNew) {
      setVals(newVals);
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);
};
