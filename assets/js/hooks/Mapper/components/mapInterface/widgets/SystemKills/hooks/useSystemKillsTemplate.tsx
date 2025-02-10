// useSystemKillsItemTemplate.tsx
import { useCallback } from 'react';
import { VirtualScrollerTemplateOptions } from 'primereact/virtualscroller';
import { DetailedKill } from '@/hooks/Mapper/types/kills';
import { KillItemTemplate } from '../components/KillItemTemplate';

export function useSystemKillsItemTemplate(
  systemNameMap: Record<string, string>,
  compact: boolean,
  onlyOneSystem: boolean,
) {
  return useCallback(
    (kill: DetailedKill, options: VirtualScrollerTemplateOptions) =>
      KillItemTemplate(systemNameMap, compact, onlyOneSystem, kill, options),
    [systemNameMap, compact, onlyOneSystem],
  );
}
