import { FC, useState, useEffect, useRef } from 'react';

const calibratedDate = new Date('Mon, 01 Jan 2024 00:00:00 GMT');

interface TimeLeftProps {
  cDate?: Date;
}

export const TimeLeft: FC<TimeLeftProps> = ({ cDate = new Date() }) => {
  const [date, setDate] = useState<Date>(cDate);
  const [timeDiff, setTimeDiff] = useState<string>('');
  const timerId = useRef<number | undefined>(undefined);

  useEffect(() => {
    update();
    startTimer();

    return () => {
      if (timerId.current !== undefined) {
        clearTimeout(timerId.current);
      }
    };
  }, [date]);

  const startTimer = () => {
    timerId.current = window.setTimeout(() => {
      update();
      startTimer();
    }, 1000);
  };

  const update = () => {
    const currentDate = new Date();
    const diff = currentDate.getTime() + currentDate.getTimezoneOffset() * 60000 - date.getTime();
    setTimeDiff(calculateTimeDiff(diff));
  };

  const calculateTimeDiff = (_milliseconds: number) => {
    const relativeDate = new Date(calibratedDate.getTime() + _milliseconds);
    const seconds = relativeDate.getUTCSeconds().toString().padStart(2, '0');
    const minutes = relativeDate.getUTCMinutes().toString().padStart(2, '0');
    const hours = relativeDate.getUTCHours().toString().padStart(2, '0');
    const days = (relativeDate.getUTCDate() - 1).toString();

    return `${days} ${hours}:${minutes}:${seconds}`;
  };

  useEffect(() => {
    setDate(cDate);
    update();
  }, [cDate]);

  return <span className="whitespace-nowrap">{timeDiff}</span>;
};
