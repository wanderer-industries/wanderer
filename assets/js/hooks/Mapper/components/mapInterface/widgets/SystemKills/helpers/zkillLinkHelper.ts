const zkillboardBaseURL = 'https://zkillboard.com';

export function zkillLink(type: 'kill' | 'character' | 'corporation' | 'alliance', id?: number | null): string {
  if (!id) return `${zkillboardBaseURL}`;
  if (type === 'kill') return `${zkillboardBaseURL}/kill/${id}/`;
  if (type === 'character') return `${zkillboardBaseURL}/character/${id}/`;
  if (type === 'corporation') return `${zkillboardBaseURL}/corporation/${id}/`;
  if (type === 'alliance') return `${zkillboardBaseURL}/alliance/${id}/`;
  return `${zkillboardBaseURL}`;
}
