import { WindowProps } from '@/hooks/Mapper/components/ui-kit/WindowManager/WindowManager.tsx';

export function getWindowsBySides(windows: WindowProps[], containerWidth: number, containerHeight: number) {
  const centerX = containerWidth / 2;
  const centerY = containerHeight / 2;

  const top = windows.filter(window => window.position.y + window.size.height / 2 < centerY);
  const bottom = windows.filter(window => window.position.y + window.size.height / 2 >= centerY);
  const left = windows.filter(window => window.position.x + window.size.width / 2 < centerX);
  const right = windows.filter(window => window.position.x + window.size.width / 2 >= centerX);

  return { top, bottom, left, right };
}
