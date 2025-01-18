export function formatKillTime(killTime?: string): string | null {
  if (!killTime) return null;

  const dt = new Date(killTime);
  const now = new Date();

  const isSameDay =
    dt.getDate() === now.getDate() && dt.getMonth() === now.getMonth() && dt.getFullYear() === now.getFullYear();

  if (isSameDay) {
    const hh = dt.getHours().toString().padStart(2, '0');
    const mm = dt.getMinutes().toString().padStart(2, '0');
    return `Today ${hh}:${mm}`;
  } else {
    const opts: Intl.DateTimeFormatOptions = { month: 'short', day: 'numeric' };
    return dt.toLocaleString('default', opts);
  }
}
