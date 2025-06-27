import { Dialog } from 'primereact/dialog';
import { FleetReadinessContent } from './FleetReadinessContent';
import { useEffect, useState, useCallback } from 'react';
import { Button } from 'primereact/button';
import { PrimeIcons } from 'primereact/api';
import { useMapRootState } from '@/hooks/Mapper/mapRootProvider';
import { OutCommand, TrackingCharacter } from '@/hooks/Mapper/types';

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
  const { outCommand } = useMapRootState();
  const [readyCount, setReadyCount] = useState<number>(0);
  const [refreshTrigger, setRefreshTrigger] = useState<number>(0);
  const [isClearing, setIsClearing] = useState<boolean>(false);
  const [rateLimitInfo, setRateLimitInfo] = useState<{
    isRateLimited: boolean;
    remainingCooldown: number;
    message: string;
  } | null>(null);

  // Load ready characters count for header
  useEffect(() => {
    if (visible) {
      const loadReadyCount = async () => {
        try {
          const res = await outCommand({
            type: OutCommand.getAllReadyCharacters,
            data: {},
          });
          const responseData = res as { data?: { characters?: TrackingCharacter[] } };
          const allCharacters = responseData?.data?.characters || [];
          setReadyCount(allCharacters.length);
        } catch (err) {
          console.error('Failed to load ready characters count:', err);
          setReadyCount(0);
        }
      };
      loadReadyCount();
    }
  }, [visible, outCommand, refreshTrigger]);

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

      // Refresh the ready count
      setReadyCount(0);
      setRefreshTrigger(prev => prev + 1);
    } catch (error: unknown) {
      // Handle server-side rate limiting
      const errorObj = error as RateLimitError;
      if (errorObj?.error === 'rate_limited') {
        setRateLimitInfo({
          isRateLimited: true,
          remainingCooldown: errorObj.remaining_cooldown || 0,
          message: errorObj.message || 'Clear all function is on cooldown',
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
      <FleetReadinessContent refreshTrigger={refreshTrigger} />
    </Dialog>
  );
};
