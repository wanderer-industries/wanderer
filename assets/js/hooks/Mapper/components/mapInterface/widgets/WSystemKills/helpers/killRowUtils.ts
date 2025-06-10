import { DetailedKill } from '@/hooks/Mapper/types/kills';

/** Returns "5m ago", "3h ago", "2.5d ago", etc. */
export function formatTimeMixed(killTime: string): string {
  const killDate = new Date(killTime);
  const diffMs = Date.now() - killDate.getTime();
  const diffHours = diffMs / (1000 * 60 * 60);

  if (diffHours < 1) {
    const mins = Math.round(diffHours * 60);
    return `${mins}m ago`;
  } else if (diffHours < 24) {
    const hours = Math.round(diffHours);
    return `${hours}h ago`;
  } else {
    const days = diffHours / 24;
    const roundedDays = days.toFixed(1);
    return `${roundedDays}d ago`;
  }
}

/** Formats integer ISK values into k/M/B/T. */
export function formatISK(value: number): string {
  if (value >= 1_000_000_000_000) {
    return `${(value / 1_000_000_000_000).toFixed(2)}T`;
  } else if (value >= 1_000_000_000) {
    return `${(value / 1_000_000_000).toFixed(2)}B`;
  } else if (value >= 1_000_000) {
    return `${(value / 1_000_000).toFixed(2)}M`;
  } else if (value >= 1_000) {
    return `${(value / 1_000).toFixed(2)}k`;
  }
  return Math.round(value).toString();
}

export function getAttackerSubscript(kill: DetailedKill | undefined) {
  if (!kill) {
    return null;
  }
  if (kill.npc) {
    return { label: 'npc', cssClass: 'text-purple-400' };
  }
  const count = kill.attacker_count ?? 0;
  if (count === 1) {
    return { label: 'solo', cssClass: 'text-green-400' };
  } else if (count > 1) {
    return { label: String(count), cssClass: 'text-white' };
  }
  return null;
}
