import { PingRoute } from '@/hooks/Mapper/components/mapInterface/components/PingsInterface/PingRoute.tsx';
import {
  CharacterCardById,
  SystemView,
  TimeAgo,
  TooltipPosition,
  WdButton,
  WdImgButton,
  WdImgButtonTooltip,
} from '@/hooks/Mapper/components/ui-kit';
import { emitMapEvent } from '@/hooks/Mapper/events';
import { useMapRootState } from '@/hooks/Mapper/mapRootProvider';
import { PingsPlacement } from '@/hooks/Mapper/mapRootProvider/types.ts';
import { Commands, OutCommand, PingType } from '@/hooks/Mapper/types';
import clsx from 'clsx';
import { PrimeIcons } from 'primereact/api';
import { ConfirmPopup } from 'primereact/confirmpopup';
import { Toast } from 'primereact/toast';
import { useCallback, useEffect, useMemo, useRef } from 'react';
import useRefState from 'react-usestateref';
import { useConfirmPopup } from '@/hooks/Mapper/hooks';

const PING_PLACEMENT_MAP = {
  [PingsPlacement.rightTop]: 'top-right',
  [PingsPlacement.leftTop]: 'top-left',
  [PingsPlacement.rightBottom]: 'bottom-right',
  [PingsPlacement.leftBottom]: 'bottom-left',
};

const PING_PLACEMENT_MAP_OFFSETS = {
  [PingsPlacement.rightTop]: { default: '!top-[56px]', withLeftMenu: '!top-[56px] !right-[64px]' },
  [PingsPlacement.rightBottom]: { default: '!bottom-[15px]', withLeftMenu: '!bottom-[15px] !right-[64px]' },
  [PingsPlacement.leftTop]: { default: '!top-[56px] !left-[64px]', withLeftMenu: '!top-[56px] !left-[64px]' },
  [PingsPlacement.leftBottom]: { default: '!left-[64px] !bottom-[15px]', withLeftMenu: '!bottom-[15px]' },
};

const CLOSE_TOOLTIP_PROPS: WdImgButtonTooltip = {
  content: 'Hide',
  position: TooltipPosition.top,
  className: '!leading-[0]',
};

const NAVIGATE_TOOLTIP_PROPS: WdImgButtonTooltip = {
  content: 'Navigate To',
  position: TooltipPosition.top,
  className: '!leading-[0]',
};

const DELETE_TOOLTIP_PROPS: WdImgButtonTooltip = {
  content: 'Remove',
  position: TooltipPosition.top,
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
  const { cfShow, cfHide, cfVisible, cfRef } = useConfirmPopup();

  const {
    storedSettings: { interfaceSettings },
    data: { pings, selectedSystems },
    outCommand,
  } = useMapRootState();

  const selectedSystem = useMemo(() => {
    if (selectedSystems.length !== 1) {
      return null;
    }

    return selectedSystems[0];
  }, [selectedSystems]);

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

  const removePing = useCallback(async () => {
    if (!ping) {
      return;
    }

    await outCommand({
      type: OutCommand.cancelPing,
      data: { type: ping.type, id: ping.id },
    });
  }, [outCommand, ping]);

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

  const { placement, offsets } = useMemo(() => {
    const rawPlacement =
      interfaceSettings.pingsPlacement == null ? PingsPlacement.rightTop : interfaceSettings.pingsPlacement;

    return {
      placement: PING_PLACEMENT_MAP[rawPlacement],
      offsets: PING_PLACEMENT_MAP_OFFSETS[rawPlacement],
    };
  }, [interfaceSettings]);

  if (!ping) {
    return null;
  }

  const isShowSelectedSystem = selectedSystem != null && selectedSystem !== ping.solar_system_id;

  return (
    <>
      <Toast
        position={placement as never}
        className={clsx('!max-w-[initial] w-[500px]', hasLeftOffset ? offsets.withLeftMenu : offsets.default)}
        ref={toast}
        content={({ message }) => (
          <section
            className={clsx(
              'flex flex-col p-3 w-full border border-stone-800 shadow-md animate-fadeInDown rounded-[5px]',
              'bg-gradient-to-tr from-transparent to-sky-700/60 bg-stone-900/70',
            )}
          >
            <div className="flex gap-3">
              <i className={clsx('pi text-yellow-500 text-2xl', 'relative top-[2px]', ICONS[ping.type])}></i>
              <div className="flex flex-col gap-1 w-full">
                <div className="flex justify-between">
                  <div>
                    <div className="m-0 font-semibold text-base text-white">{TITLES[ping.type]}</div>

                    <div className="flex gap-1 items-center">
                      {isShowSelectedSystem && (
                        <>
                          <SystemView systemId={selectedSystem} />
                          <span className="pi pi-angle-double-right text-[10px] relative top-[1px] text-stone-400" />
                        </>
                      )}
                      <SystemView systemId={ping.solar_system_id} />
                      {isShowSelectedSystem && (
                        <WdImgButton
                          className={clsx(PrimeIcons.QUESTION_CIRCLE, 'ml-[2px] relative top-[-2px] !text-[10px]')}
                          tooltip={{
                            position: TooltipPosition.top,
                            content: (
                              <div className="flex flex-col gap-1">
                                The settings for the route are taken from the Routes settings and can be configured
                                through them.
                              </div>
                            ),
                          }}
                        />
                      )}
                    </div>
                  </div>
                  <div className="flex flex-col items-end">
                    <CharacterCardById className="" characterId={ping.character_eve_id} simpleMode />
                    <TimeAgo timestamp={ping.inserted_at.toString()} className="text-stone-400 text-[11px]" />
                  </div>
                </div>

                {selectedSystem != null && <PingRoute />}

                <p className="m-0 text-[13px] text-stone-200 min-h-[20px] pr-[16px]">{message.detail}</p>
              </div>

              <WdImgButton
                className={clsx(PrimeIcons.TIMES, 'hover:text-red-400 mt-[3px]')}
                tooltip={CLOSE_TOOLTIP_PROPS}
                onClick={handleClickHide}
              />
            </div>

            {/*Button bar*/}
            <div className="flex justify-end items-center gap-2 h-0 relative top-[-8px]">
              <WdImgButton
                className={clsx('pi-compass', 'hover:text-red-400 mt-[3px]')}
                tooltip={NAVIGATE_TOOLTIP_PROPS}
                onClick={navigateTo}
              />

              {/*@ts-ignore*/}
              <div ref={cfRef}>
                <WdImgButton
                  className={clsx('pi-trash', 'text-red-400 hover:text-red-300')}
                  tooltip={DELETE_TOOLTIP_PROPS}
                  onClick={cfShow}
                />
              </div>
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

      <WdButton
        icon="pi pi-bell"
        severity="warning"
        aria-label="Notification"
        size="small"
        className="w-[33px] h-[33px]"
        outlined
        onClick={handleClickShow}
        disabled={isShow}
      />

      <ConfirmPopup
        target={cfRef.current}
        visible={cfVisible}
        onHide={cfHide}
        message="Are you sure you want to delete ping?"
        icon="pi pi-exclamation-triangle text-orange-400"
        accept={removePing}
      />
    </>
  );
};
