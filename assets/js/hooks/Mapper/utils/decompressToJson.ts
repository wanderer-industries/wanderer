import pako from 'pako';

export const decompressToJson = (base64string: string) => {
  const base64_decoded = atob(base64string);
  const charData = base64_decoded.split('').map(function (x) {
    return x.charCodeAt(0);
  });
  const zlibData = new Uint8Array(charData);
  const inflatedData = pako.inflate(zlibData, {
    to: 'string',
  });

  return JSON.parse(inflatedData);
};
