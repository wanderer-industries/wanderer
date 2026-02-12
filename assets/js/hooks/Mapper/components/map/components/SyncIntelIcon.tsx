import clsx from 'clsx';
import { TooltipPosition, WdTooltipWrapper } from '@/hooks/Mapper/components/ui-kit';
import { OutCommand } from '@/hooks/Mapper/types';

interface SyncIntelIconProps {
  solarSystemId: string;
  outCommand: (cmd: { type: OutCommand.syncIntel; data: { solar_system_id: string } }) => void;
}

export const SyncIntelIcon = ({ solarSystemId, outCommand }: SyncIntelIconProps) => (
  <WdTooltipWrapper
    className="h-[15px] transform -translate-y-[6%]"
    position={TooltipPosition.top}
    content="Sync intel from source"
  >
    <button
      type="button"
      aria-label="Sync intel from source"
      className={clsx(
        'pi pi-sync',
        'text-[8px] cursor-pointer text-blue-400 hover:text-blue-200',
      )}
      onClick={(e) => {
        e.stopPropagation();
        outCommand({
          type: OutCommand.syncIntel,
          data: { solar_system_id: solarSystemId },
        });
      }}
    />
  </WdTooltipWrapper>
);
