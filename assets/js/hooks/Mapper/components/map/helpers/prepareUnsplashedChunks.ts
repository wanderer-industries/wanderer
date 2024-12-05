// Helper function to split an array into chunks of size
const chunkArray = (array: any[], size: number) => {
  const chunks = [];
  for (let i = 0; i < array.length; i += size) {
    chunks.push(array.slice(i, i + size));
  }
  return chunks;
};

export const prepareUnsplashedChunks = (items: any[]) => {
  // Split the items into chunks of 4
  const chunks = chunkArray(items, 4);

  // Get the column elements
  const leftColumn: any[] = [];
  const rightColumn: any[] = [];

  chunks.forEach((chunk, index) => {
    const column = index % 2 === 0 ? leftColumn : rightColumn;

    chunk.forEach(item => {
      column.push(item);
    });
  });

  return [leftColumn, rightColumn];
};
