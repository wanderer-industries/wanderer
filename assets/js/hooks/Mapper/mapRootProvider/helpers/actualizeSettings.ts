type Settings = Record<string, unknown>;

export const actualizeSettings = <T extends Settings>(defaultVals: T, vals: T, setVals: (newVals: T) => void) => {
  let foundNew = false;

  const newVals = Object.keys(defaultVals).reduce((acc, key) => {
    if (key in acc) {
      return acc;
    }

    foundNew = true;

    return {
      ...acc,
      [key]: defaultVals[key],
    };
  }, vals);

  if (foundNew) {
    setVals(newVals);
  }
};
