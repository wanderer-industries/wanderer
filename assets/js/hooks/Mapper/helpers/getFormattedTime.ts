export function getFormattedTime() {
  const now = new Date();

  const hours = String(now.getHours()).padStart(2, '0');
  const minutes = String(now.getMinutes()).padStart(2, '0');
  const seconds = String(now.getSeconds()).padStart(2, '0');

  const ms = String(now.getMilliseconds() + 1000).slice(1);

  return `${hours}:${minutes}:${seconds} ${ms}`;
}
