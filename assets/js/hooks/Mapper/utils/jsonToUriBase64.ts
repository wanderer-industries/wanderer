export const encodeJsonToUriBase64 = (value: unknown): string => {
  const json = JSON.stringify(value);
  const uriEncoded = encodeURIComponent(json);

  if (typeof window !== 'undefined' && typeof window.btoa === 'function') {
    return window.btoa(uriEncoded);
  }
  // Node.js
  // @ts-ignore
  return Buffer.from(uriEncoded, 'utf8').toString('base64');
};

export const decodeUriBase64ToJson = <T = unknown>(base64: string): T => {
  let uriEncoded: string;

  if (typeof window !== 'undefined' && typeof window.atob === 'function') {
    uriEncoded = window.atob(base64);
  } else {
    // Node.js
    // @ts-ignore
    uriEncoded = Buffer.from(base64, 'base64').toString('utf8');
  }

  const json = decodeURIComponent(uriEncoded);
  return JSON.parse(json) as T;
};
