const baseImageURL = 'https://images.evetech.net';

export function eveImageUrl(
  category: 'characters' | 'corporations' | 'alliances' | 'types',
  id?: number | null,
  variation: string = 'icon',
  size?: number,
): string | undefined {
  if (!id || id <= 0) {
    return undefined;
  }

  let url = `${baseImageURL}/${category}/${id}/${variation}`;
  if (size) {
    url += `?size=${size}`;
  }
  return url;
}
