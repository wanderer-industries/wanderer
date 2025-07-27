import { Dialog } from 'primereact/dialog';
import { FleetReadinessContent } from './FleetReadinessContent';
import { useState, useCallback, useEffect } from 'react';
import { Button } from 'primereact/button';
import { PrimeIcons } from 'primereact/api';
import { useMapRootState } from '@/hooks/Mapper/mapRootProvider';
import { OutCommand } from '@/hooks/Mapper/types';

interface FleetReadinessProps {
  visible: boolean;
  onHide: () => void;
}

interface RateLimitError {
  error: string;
  message: string;
  remaining_cooldown: number;
}

export const FleetReadiness = ({ visible, onHide }: FleetReadinessProps) => {
  const { outCommand, data } = useMapRootState();
  const [isClearing, setIsClearing] = useState<boolean>(false);
  const [rateLimitInfo, setRateLimitInfo] = useState<{
    isRateLimited: boolean;
    remainingCooldown: number;
    message: string;
  } | null>(null);

  // Derive ready count from global state
  const readyCount = data.characters.filter(char => char.ready).length;

  const canClearAll = !isClearing && readyCount > 0 && !rateLimitInfo?.isRateLimited;

  const formatCooldownTime = (milliseconds: number) => {
    const minutes = Math.floor(milliseconds / 60000);
    const seconds = Math.floor((milliseconds % 60000) / 1000);
    return `${minutes}:${seconds.toString().padStart(2, '0')}`;
  };

  const handleClearAll = useCallback(async () => {
    if (!canClearAll) return;

    setIsClearing(true);
    setRateLimitInfo(null);

    try {
      await outCommand({
        type: OutCommand.clearAllReadyCharacters,
        data: {},
      });
    } catch (error: unknown) {
      // Handle server-side rate limiting with runtime check
      const isRateLimitError = (err: unknown): err is RateLimitError => {
        return (
          typeof err === 'object' &&
          err !== null &&
          'error' in err &&
          'message' in err &&
          'remaining_cooldown' in err &&
          (err as { error: unknown }).error === 'rate_limited'
        );
      };

      if (isRateLimitError(error)) {
        setRateLimitInfo({
          isRateLimited: true,
          remainingCooldown: error.remaining_cooldown || 0,
          message: error.message || 'Clear all function is on cooldown',
        });
      } else {
        console.error('Failed to clear ready characters:', error);
      }
    } finally {
      setIsClearing(false);
    }
  }, [canClearAll, outCommand]);

  // Update cooldown timer
  useEffect(() => {
    if (!rateLimitInfo?.isRateLimited) return;

    const timer = setInterval(() => {
      setRateLimitInfo(prev => {
        if (!prev) return null;

        const newCooldown = Math.max(0, prev.remainingCooldown - 100);
        if (newCooldown === 0) {
          return null; // Clear rate limit info when cooldown expires
        }

        return {
          ...prev,
          remainingCooldown: newCooldown,
        };
      });
    }, 100);

    return () => clearInterval(timer);
  }, [rateLimitInfo?.isRateLimited]);

  const tooltipMessage = rateLimitInfo?.isRateLimited
    ? `Clear (available in ${formatCooldownTime(rateLimitInfo.remainingCooldown)})`
    : 'Clear';

  const dialogHeader = (
    <div className="flex justify-between items-center w-full">
      <span>{`Fleet Readiness (${readyCount})`}</span>
      {readyCount > 0 && (
        <Button
          icon={PrimeIcons.TIMES_CIRCLE}
          size="small"
          text
          disabled={!canClearAll}
          loading={isClearing}
          onClick={handleClearAll}
          tooltip={tooltipMessage}
          tooltipOptions={{ position: 'left' }}
          className="text-red-400 hover:text-red-300 hover:bg-red-500/20 transition-colors p-1"
        />
      )}
    </div>
  );

  return (
    <Dialog
      header={dialogHeader}
      visible={visible}
      onHide={onHide}
      className="w-[90vw] max-w-[700px] max-h-[90vh]"
      modal
      draggable={false}
      resizable={false}
      dismissableMask
      contentClassName="p-0 h-full flex flex-col"
    >
      <FleetReadinessContent />
    </Dialog>
  );
};
