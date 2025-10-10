import { SystemView, WdButton } from '@/hooks/Mapper/components/ui-kit';
import { useMapRootState } from '@/hooks/Mapper/mapRootProvider';
import { OutCommand } from '@/hooks/Mapper/types';
import { PingType } from '@/hooks/Mapper/types/ping.ts';
import clsx from 'clsx';
import { Dialog } from 'primereact/dialog';
import { InputTextarea } from 'primereact/inputtextarea';
import { useCallback, useRef, useState } from 'react';

const PING_TITLES = {
  [PingType.Rally]: 'RALLY',
  [PingType.Alert]: 'ALERT',
};

interface SystemPingDialogProps {
  systemId: string;
  type: PingType;
  visible: boolean;
  setVisible: (visible: boolean) => void;
}

export const SystemPingDialog = ({ systemId, type, visible, setVisible }: SystemPingDialogProps) => {
  const { outCommand } = useMapRootState();

  const [message, setMessage] = useState('');
  const inputRef = useRef<HTMLTextAreaElement>();

  const ref = useRef({ message, outCommand, systemId, type });
  ref.current = { message, outCommand, systemId, type };

  const handleSave = useCallback(() => {
    const { message, outCommand, systemId, type } = ref.current;

    outCommand({
      type: OutCommand.addPing,
      data: {
        solar_system_id: systemId,
        type,
        message,
      },
    });
    setVisible(false);
  }, [setVisible]);

  const onShow = useCallback(() => {
    inputRef.current?.focus();
  }, []);

  return (
    <Dialog
      header={
        <div className="flex gap-1 text-[13px] items-center text-stone-300">
          <div>Ping:{` `}</div>
          <div
            className={clsx({
              ['text-cyan-400']: type === PingType.Rally,
            })}
          >
            {PING_TITLES[type]}
          </div>
          <div className="text-[11px]">in</div> <SystemView systemId={systemId} className="relative top-[1px]" />
        </div>
      }
      visible={visible}
      draggable={true}
      style={{ width: '450px' }}
      onShow={onShow}
      onHide={() => {
        if (!visible) {
          return;
        }

        setVisible(false);
      }}
    >
      <form onSubmit={handleSave}>
        <div className="flex flex-col gap-3 px-2">
          <div className="flex flex-col gap-1">
            <label className="text-[11px]" htmlFor="username">
              Message
            </label>
            <InputTextarea
              // @ts-ignore
              ref={inputRef}
              autoResize
              rows={3}
              cols={30}
              value={message}
              onChange={e => setMessage(e.target.value)}
            />
          </div>

          <div className="flex gap-2 justify-end">
            <WdButton type="submit" onClick={handleSave} size="small" severity="danger" label="Ping!" />
          </div>
        </div>
      </form>
    </Dialog>
  );
};
