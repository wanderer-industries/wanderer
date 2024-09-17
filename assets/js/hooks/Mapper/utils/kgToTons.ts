const formatWithSpaces = (num: number): string => {
  return num.toString().replace(/\B(?=(\d{3})+(?!\d))/g, ' ');
};

export const kgToTons = (kg: number): string => {
  const tons = kg / 1000;

  let formattedTons: string;

  if (tons >= 1000000) {
    formattedTons = `${(tons / 1000000).toFixed(1)}M t`;
  } else if (tons >= 100000) {
    formattedTons = `${formatWithSpaces(Math.floor(tons))}k t`;
  } else {
    formattedTons = `${formatWithSpaces(parseFloat(tons.toFixed(3)))} t`;
  }

  return formattedTons;
};
