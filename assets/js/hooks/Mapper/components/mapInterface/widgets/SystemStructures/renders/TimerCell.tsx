// File: TimerCell.tsx
import React, { useEffect, useState } from 'react';
import { StructureStatus } from '../helpers/structureTypes';
import { statusesRequiringTimer } from '../helpers';

interface TimerCellProps {
  endTime?: string;
  status: StructureStatus;
}

function TimerCellImpl({ endTime, status }: TimerCellProps) {
  const [now, setNow] = useState(() => Date.now());

  useEffect(() => {
    if (!endTime || !statusesRequiringTimer.includes(status)) {
      return;
    }

    const intervalId = setInterval(() => {
      setNow(Date.now());
    }, 1000);

    return () => clearInterval(intervalId);
  }, [endTime, status]);

  if (!statusesRequiringTimer.includes(status)) {
    return <span className="text-stone-400"></span>;
  }
  if (!endTime) {
    return <span className="text-sky-400">Set Timer</span>;
  }

  const msLeft = new Date(endTime).getTime() - now;
  if (msLeft <= 0) {
    return <span className="text-red-500">00:00:00</span>;
  }

  const sec = Math.floor(msLeft / 1000) % 60;
  const min = Math.floor(msLeft / (1000 * 60)) % 60;
  const hr = Math.floor(msLeft / (1000 * 3600));

  const pad = (n: number) => n.toString().padStart(2, '0');
  return (
    <span className="text-sky-400">
      {pad(hr)}:{pad(min)}:{pad(sec)}
    </span>
  );
}

export const TimerCell = React.memo(TimerCellImpl);
