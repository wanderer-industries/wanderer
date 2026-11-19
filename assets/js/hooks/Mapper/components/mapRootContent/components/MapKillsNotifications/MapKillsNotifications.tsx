import clsx from 'clsx';
import { Toast } from 'primereact/toast';
import type { FC } from 'react';

import { PingsPlacement } from '@/hooks/Mapper/mapRootProvider/types.ts';
import styles from './MapKillsNotifications.module.scss';
import { useMapKillsNotifications } from './useMapKillsNotifications.tsx';

export interface MapKillsNotificationsProps {}

export const MapKillsNotifications: FC<MapKillsNotificationsProps> = () => {
  const { toastRef, hasPing, isShowMenu, pingsPlacement } = useMapKillsNotifications();
  const hasRightTopPing = hasPing && pingsPlacement === PingsPlacement.rightTop;
  const topOffsetClass = hasRightTopPing ? '!top-[156px]' : '!top-[56px]';
  const rightOffsetClass = isShowMenu ? '!right-[20px]' : '!right-[64px]';

  return (
    <Toast
      ref={toastRef}
      position="top-right"
      className={clsx('!max-w-[30rem]', styles.toastList, topOffsetClass, rightOffsetClass)}
    />
  );
};
