import { useEffect, useState, useRef } from 'react';
import { WithClassName } from '@/hooks/Mapper/types/common.ts';

interface TimeAgoProps {
  timestamp: string; // Теперь тип string, так как приходит ISO 8601 строка
}

export const TimeAgo = ({ timestamp, className }: TimeAgoProps & WithClassName) => {
  const [timeAgo, setTimeAgo] = useState<string>('');
  const timeoutIdRef = useRef<number | null>(null);

  useEffect(() => {
    const updateTimeAgo = () => {
      setTimeAgo(calculateTimeAgo(timestamp));
      startTimer();
    };

    const handleVisibilityChange = () => {
      if (document.hidden) {
        if (timeoutIdRef.current !== null) {
          clearTimeout(timeoutIdRef.current);
        }
      } else {
        updateTimeAgo();
      }
    };

    document.addEventListener('visibilitychange', handleVisibilityChange);
    updateTimeAgo(); // Initial calculation

    return () => {
      if (timeoutIdRef.current !== null) {
        clearTimeout(timeoutIdRef.current);
      }
      document.removeEventListener('visibilitychange', handleVisibilityChange);
    };
  }, [timestamp]);

  const startTimer = () => {
    const now = new Date();
    const diff = now.getTime() - new Date(timestamp).getTime();
    const nextUpdateIn = diff < 60000 ? 1000 : 60000; // Обновление каждые секунды или каждую минуту

    timeoutIdRef.current = window.setTimeout(() => {
      setTimeAgo(calculateTimeAgo(timestamp));
      startTimer();
    }, nextUpdateIn);
  };

  const calculateTimeAgo = (utcDateString: string): string => {
    const now = new Date();
    const date = new Date(utcDateString); // Парсим строку в объект Date

    // Нет необходимости корректировать на часовой пояс, так как `new Date(utcDateString)` уже делает это
    const diff = now.getTime() - date.getTime();

    const seconds = Math.floor(diff / 1000);
    const minutes = Math.floor(seconds / 60);
    const hours = Math.floor(minutes / 60);
    const days = Math.floor(hours / 24);

    if (seconds < 60) return `${seconds} seconds ago`;
    if (minutes < 60) return `${minutes} min ago`;
    if (hours < 24) return `${hours} hours ago`;
    return `${days} days ago`;
  };

  return <span className={className}>{timeAgo}</span>;
};
