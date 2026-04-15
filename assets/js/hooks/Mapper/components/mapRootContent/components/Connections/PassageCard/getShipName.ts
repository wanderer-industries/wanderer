const SHIP_NAME_RX = /u'|'/g;

export const getShipName = (name: string) => {
  return name
    .replace(SHIP_NAME_RX, '')
    .replace(/\\u([\dA-Fa-f]{4})/g, (_, grp) => {
      return String.fromCharCode(parseInt(grp, 16));
    })
    .replace(/\\x([\dA-Fa-f]{2})/g, (_, grp) => {
      return String.fromCharCode(parseInt(grp, 16));
    });
};
