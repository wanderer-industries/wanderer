/**
 * Constants for EVE Online image URLs
 */
const BASE_IMAGE_URL = 'https://images.evetech.net';

/**
 * Generates a URL for any EVE Online image resource
 * @param category - The category of the image (characters, corporations, alliances, types)
 * @param id - The EVE Online ID of the entity
 * @param variation - The variation of the image (icon, portrait, render, logo)
 * @param size - The size of the image (optional)
 * @returns The URL to the EVE Online image, or null if the ID is invalid
 */
export const getEveImageUrl = (
  category: 'characters' | 'corporations' | 'alliances' | 'types',
  id?: number | string | null,
  variation: string = 'icon',
  size?: number,
): string | null => {
  if (!id || (typeof id === 'number' && id <= 0)) {
    return null;
  }

  let url = `${BASE_IMAGE_URL}/${category}/${id}/${variation}`;
  if (size) {
    url += `?size=${size}`;
  }

  return url;
};

/**
 * Generates the URL for an EVE Online character portrait
 * @param characterEveId - The EVE Online character ID
 * @param size - The size of the portrait (default: 64)
 * @returns The URL to the character's portrait, or an empty string if the ID is invalid
 */
export const getCharacterPortraitUrl = (characterEveId: string | number | undefined, size: number = 64): string => {
  const portraitUrl = getEveImageUrl('characters', characterEveId, 'portrait', size);
  return portraitUrl || '';
};
