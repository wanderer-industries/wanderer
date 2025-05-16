import { Button } from 'primereact/button';
import { useCallback, useEffect, useMemo, useRef } from 'react';
import { Toast } from 'primereact/toast';
import clsx from 'clsx';
import { useMapRootState } from '@/hooks/Mapper/mapRootProvider';
import { Commands, PingType } from '@/hooks/Mapper/types';
import {
  CharacterCardById,
  SystemView,
  TimeAgo,
  TooltipPosition,
  WdImgButton,
  WdImgButtonTooltip,
} from '@/hooks/Mapper/components/ui-kit';
import useRefState from 'react-usestateref';
import { PrimeIcons } from 'primereact/api';
import { emitMapEvent } from '@/hooks/Mapper/events';

const CLOSE_TOOLTIP_PROPS: WdImgButtonTooltip = {
  content: 'Close',
  position: TooltipPosition.top,
  className: '!leading-[0]',
};

const NAVIGATE_TOOLTIP_PROPS: WdImgButtonTooltip = {
  content: 'Navigate To',
  position: TooltipPosition.bottom,
  className: '!leading-[0]',
};

// const TOOLTIP_WAYPOINT_PROPS: WdImgButtonTooltip = {
//   content: 'Waypoint',
//   position: TooltipPosition.bottom,
//   className: '!leading-[0]',
// };

const TITLES = {
  [PingType.Alert]: 'Alert',
  [PingType.Rally]: 'Rally Point',
};

const ICONS = {
  [PingType.Alert]: 'pi-bell',
  [PingType.Rally]: 'pi-bell',
};

export interface PingsInterfaceProps {
  hasLeftOffset?: boolean;
}

// TODO: right now can be one ping. But in future will be multiple pings then:
//  1. we will use this as container
//  2. we will create PingInstance (which will contains ping Button and Toast
//  3. ADD Context menu
export const PingsInterface = ({ hasLeftOffset }: PingsInterfaceProps) => {
  const toast = useRef<Toast>(null);
  const [isShow, setIsShow, isShowRef] = useRefState(false);

  const {
    data: { pings },
  } = useMapRootState();

  const ping = useMemo(() => (pings.length === 1 ? pings[0] : null), [pings]);

  const navigateTo = useCallback(() => {
    if (!ping) {
      return;
    }

    emitMapEvent({
      name: Commands.centerSystem,
      data: ping.solar_system_id?.toString(),
    });
  }, [ping]);

  useEffect(() => {
    if (!ping) {
      return;
    }

    const tid = setTimeout(() => {
      toast.current?.replace({ severity: 'warn', detail: ping.message });
      setIsShow(true);
    }, 200);

    return () => clearTimeout(tid);
  }, [ping]);

  const handleClickShow = useCallback(() => {
    if (!ping) {
      return;
    }

    if (!isShowRef.current) {
      toast.current?.show({ severity: 'warn', detail: ping.message });
      setIsShow(true);
      return;
    }
    toast.current?.clear();
    setIsShow(false);
  }, [ping]);

  const handleClickHide = useCallback(() => {
    toast.current?.clear();
    setIsShow(false);
  }, []);

  if (!ping) {
    return null;
  }

  return (
    <>
      <Toast
        className={clsx('!top-[56px]', {
          ['!right-[64px]']: hasLeftOffset,
        })}
        ref={toast}
        content={({ message }) => (
          <section
            className={clsx(
              'flex flex-col p-3 w-full border border-stone-800 shadow-md animate-fadeInDown rounded-[5px]',
              'bg-gradient-to-tr from-transparent to-sky-700/60 bg-stone-900/70',
            )}
          >
            <div className="flex gap-3">
              <i className={clsx('pi text-violet-500 text-2xl', 'relative top-[2px]', ICONS[ping.type])}></i>
              <div className="flex flex-col gap-1 w-full">
                <div className="flex justify-between">
                  <div>
                    <div className="m-0 font-semibold text-base text-white">{TITLES[ping.type]}</div>
                    <SystemView systemId={ping.solar_system_id} />
                  </div>
                  <div className="flex flex-col items-end">
                    <CharacterCardById className="" characterId={ping.character_eve_id} simpleMode />
                    <TimeAgo timestamp={ping.inserted_at.toString()} className="text-stone-400 text-[11px]" />
                  </div>
                </div>

                <p className="m-0 text-[13px] text-stone-200 min-h-[20px] pr-[16px]">{message.detail}</p>
              </div>

              <WdImgButton
                className={clsx(PrimeIcons.TIMES, 'hover:text-red-400 mt-[3px]')}
                tooltip={CLOSE_TOOLTIP_PROPS}
                onClick={handleClickHide}
              />
            </div>

            {/*Button bar*/}
            <div className="flex justify-end gap-2 h-0 relative top-[-16px]">
              <WdImgButton
                className={clsx('pi-compass', 'hover:text-red-400 mt-[3px]')}
                tooltip={NAVIGATE_TOOLTIP_PROPS}
                onClick={navigateTo}
              />

              {/* TODO ADD solar system menu*/}
              {/*<WdImgButton*/}
              {/*  className={clsx('pi-map-marker', 'hover:text-red-400 mt-[3px]')}*/}
              {/*  tooltip={TOOLTIP_WAYPOINT_PROPS}*/}
              {/*  onClick={handleClickHide}*/}
              {/*/>*/}
            </div>
          </section>
        )}
      ></Toast>

      <Button
        icon="pi pi-bell"
        severity="warning"
        aria-label="Notification"
        size="small"
        className="w-[33px] h-[33px]"
        outlined
        onClick={handleClickShow}
        disabled={isShow}
      />
    </>
  );
};
