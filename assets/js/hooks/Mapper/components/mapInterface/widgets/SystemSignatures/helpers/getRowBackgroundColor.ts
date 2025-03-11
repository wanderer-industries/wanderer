import {
  TIME_ONE_MINUTE,
  TIME_TEN_MINUTES,
} from '@/hooks/Mapper/components/mapInterface/widgets/SystemSignatures/constants.ts';

export const getRowBackgroundColor = (date: Date | undefined): string => {
  if (!date) {
    return '';
  }

  const currentDate = new Date();
  const diff = currentDate.getTime() + currentDate.getTimezoneOffset() * TIME_ONE_MINUTE - date.getTime();

  if (diff < TIME_ONE_MINUTE) {
    return 'bg-lime-600/40 transition hover:bg-lime-600/50';
  }

  if (diff < TIME_TEN_MINUTES) {
    return 'bg-lime-700/30 transition hover:bg-lime-700/40';
  }

  return '';
};
