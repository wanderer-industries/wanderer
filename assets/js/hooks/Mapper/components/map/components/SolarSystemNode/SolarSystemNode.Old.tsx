import { memo, useMemo } from 'react';
import { Handle, Position, WrapNodeProps } from 'reactflow';
import { MapSolarSystemType } from '../../map.types';
import classes from './SolarSystemNode.module.scss';
import clsx from 'clsx';
import { useMapRootState } from '@/hooks/Mapper/mapRootProvider';
import { useMapGetOption } from '@/hooks/Mapper/mapRootProvider/hooks/api';

import {
  EFFECT_BACKGROUND_STYLES,
  LABELS_INFO,
  LABELS_ORDER,
  MARKER_BOOKMARK_BG_STYLES,
  STATUS_CLASSES,
} from '@/hooks/Mapper/components/map/constants.ts';
import { isWormholeSpace } from '@/hooks/Mapper/components/map/helpers/isWormholeSpace.ts';
import { WormholeClassComp } from '@/hooks/Mapper/components/map/components/WormholeClassComp';
import { UnsplashedSignature } from '@/hooks/Mapper/components/map/components/UnsplashedSignature';
import { useMapState } from '@/hooks/Mapper/components/map/MapProvider.tsx';
import { getSystemClassStyles, prepareUnsplashedChunks } from '@/hooks/Mapper/components/map/helpers';
import { sortWHClasses } from '@/hooks/Mapper/helpers';
import { PrimeIcons } from 'primereact/api';
import { LabelsManager } from '@/hooks/Mapper/utils/labelsManager.ts';
import { OutCommand } from '@/hooks/Mapper/types';
import { useDoubleClick } from '@/hooks/Mapper/hooks/useDoubleClick.ts';
import { REGIONS_MAP, Spaces } from '@/hooks/Mapper/constants';

const SpaceToClass: Record<string, string> = {
  [Spaces.Caldari]: classes.Caldaria,
  [Spaces.Matar]: classes.Mataria,
  [Spaces.Amarr]: classes.Amarria,
  [Spaces.Gallente]: classes.Gallente,
};

const sortedLabels = (labels: string[]) => {
  if (!labels) {
    return [];
  }

  return LABELS_ORDER.filter(x => labels.includes(x)).map(x => LABELS_INFO[x]);
};

export const getActivityType = (count: number) => {
  if (count <= 5) {
    return 'activityNormal';
  }

  if (count <= 30) {
    return 'activityWarn';
  }

  return 'activityDanger';
};

// eslint-disable-next-line react/display-name
export const SolarSystemNode = memo(({ data, selected }: WrapNodeProps<MapSolarSystemType>) => {
  const { interfaceSettings } = useMapRootState();
  const { isShowUnsplashedSignatures } = interfaceSettings;

  const isTempSystemNameEnabled = useMapGetOption('show_temp_system_name') === 'true';

  const {
    system_class,
    security,
    class_title,
    solar_system_id,
    statics,
    effect_name,
    region_name,
    region_id,
    is_shattered,
    solar_system_name,
  } = data.system_static_info;

  const signatures = data.system_signatures;

  const { locked, name, tag, status, labels, id, temporary_name: temporaryName } = data || {};

  const {
    data: {
      characters,
      wormholesData,
      hubs,
      kills,
      isConnecting,
      hoverNodeId,
      visibleNodes,
      showKSpaceBG,
      isThickConnections,
    },
    outCommand,
  } = useMapState();

  const visible = useMemo(() => visibleNodes.has(id), [id, visibleNodes]);

  const charactersInSystem = useMemo(() => {
    return characters.filter(c => c.location?.solar_system_id === solar_system_id).filter(c => c.online);
  }, [characters, solar_system_id]);

  const isWormhole = isWormholeSpace(system_class);
  const classTitleColor = useMemo(
    () => getSystemClassStyles({ systemClass: system_class, security }),
    [security, system_class],
  );
  const sortedStatics = useMemo(() => sortWHClasses(wormholesData, statics), [wormholesData, statics]);
  const lebM = useMemo(() => new LabelsManager(labels ?? ''), [labels]);
  const labelsInfo = useMemo(() => sortedLabels(lebM.list), [lebM]);
  const labelCustom = useMemo(() => lebM.customLabel, [lebM]);

  const killsCount = useMemo(() => {
    const systemKills = kills[solar_system_id];
    if (!systemKills) {
      return null;
    }
    return systemKills;
  }, [kills, solar_system_id]);

  const dbClick = useDoubleClick(() => {
    outCommand({
      type: OutCommand.openSettings,
      data: {
        system_id: solar_system_id.toString(),
      },
    });
  });


  const showHandlers = isConnecting || hoverNodeId === id;
  const dropHandler =  isConnecting ? 'all' : 'none';

  const space = showKSpaceBG ? REGIONS_MAP[region_id] : '';
  const regionClass = showKSpaceBG ? SpaceToClass[space] : null;

  const hasTempName = isTempSystemNameEnabled && temporaryName;

  // systemName: if temporary name is enabled and present, use it; otherwise use solar_system_name
  const systemName = hasTempName
    ? temporaryName
    : solar_system_name;

  // hsCustomLabel: if temporary name is enabled and present, show region_name, otherwise labelCustom
  const hsCustomLabel = hasTempName
    ? region_name
    : labelCustom;

  // whCustomLabel: default to solar_system_name; if that's falsy, use labelCustom
  const whCustomLabel = solar_system_name || labelCustom;

  // customLabel: if wormhole, use whCustomLabel; otherwise hsCustomLabel
  const customLabel = isWormhole
    ? whCustomLabel
    : hsCustomLabel;

  // whCustomName: if name differs from solar_system_name, use name; otherwise blank
  const whCustomName = (name !== solar_system_name)
    ? name
    : '';

  // hsSuffix: if name differs from solar_system_name, append name; otherwise blank
  const needsHsSuffix = (name !== solar_system_name);
  const hsSuffix = needsHsSuffix
    ? name
    : '';

  // hsCustomName: if there's a temp name, show "solar_system_name + suffix", otherwise "region_name + suffix"
  const hsCustomName = hasTempName
    ? `${solar_system_name} ${hsSuffix}`
    : `${region_name} ${hsSuffix}`;

  // customName: if wormhole, use whCustomName; otherwise hsCustomName
  const customName = isWormhole
    ? whCustomName
    : hsCustomName;

  const [unsplashedLeft, unsplashedRight] = useMemo(() => {
    if (!isShowUnsplashedSignatures) {
      return [[], []];
    }
    return prepareUnsplashedChunks(
      signatures
        .filter(s => s.group === 'Wormhole' && !s.linked_system)
        .map(s => ({
          eve_id: s.eve_id,
          type: s.type,
          custom_info: s.custom_info,
        })),
    );
  }, [isShowUnsplashedSignatures, signatures]);

  return (
    <>
      {visible && (
        <div className={classes.Bookmarks}>
          {customLabel !== '' && (
            <div className={clsx(classes.Bookmark, MARKER_BOOKMARK_BG_STYLES.custom)}>
              <span className="[text-shadow:_0_1px_0_rgb(0_0_0_/_40%)] ">{customLabel}</span>
            </div>
          )}

          {is_shattered && (
            <div className={clsx(classes.Bookmark, MARKER_BOOKMARK_BG_STYLES.shattered)}>
              <span className={clsx('pi pi-chart-pie text-[0.55rem]')} />
            </div>
          )}

          {killsCount && (
            <div className={clsx(classes.Bookmark, MARKER_BOOKMARK_BG_STYLES[getActivityType(killsCount)])}>
              <div className={clsx(classes.BookmarkWithIcon)}>
                <span className={clsx(PrimeIcons.BOLT, 'text-[0.65rem]')} />
                <span className={clsx(classes.text)}>{killsCount}</span>
              </div>
            </div>
          )}

          {labelsInfo.map(x => (
            <div key={x.id} className={clsx(classes.Bookmark, MARKER_BOOKMARK_BG_STYLES[x.id])}>
              {x.shortName}
            </div>
          ))}
        </div>
      )}
      <div
        className={clsx(
          classes.RootCustomNode,
          regionClass,
          classes[STATUS_CLASSES[status]],
          { [classes.selected]: selected },
          'flex flex-col w-[130px] h-[34px]',
          'px-[6px] pt-[2px] pb-[3px] text-[10px]',
          'leading-[1] space-y-[1px]',
          'shadow-[0_0_5px_rgba(45,45,45,0.5)]',
          'border border-[var(--pastel-blue-darken10)] rounded-[5px]',
        )}
      >
        {visible && (
          <>
            <div className={clsx(classes.HeadRow, 'flex items-center gap-[3px]')}>
              <div className={clsx(classes.classTitle, classTitleColor, '[text-shadow:_0_1px_0_rgb(0_0_0_/_40%)]')}>
                {class_title ?? '-'}
              </div>

              <div
                className={clsx(
                  classes.classSystemName,
                  'flex-grow overflow-hidden text-ellipsis whitespace-nowrap font-sans',
                )}
              >
                {systemName}
              </div>

              {isWormhole && (
                <div className={clsx(classes.statics, 'flex gap-[2px] text-[8px]')}>
                  {sortedStatics.map(x => (
                    <WormholeClassComp key={x} id={x} />
                  ))}
                </div>
              )}

              {effect_name !== null && isWormhole && (
                <div className={clsx(classes.effect, EFFECT_BACKGROUND_STYLES[effect_name])}></div>
              )}
            </div>

            <div className={clsx(classes.BottomRow, 'flex items-center gap-[3px]')}>
              <div className="flex items-center gap-2">
                {tag != null && tag !== '' && (
                    <div className={clsx(classes.TagTitle, 'font-medium')}>{`[${tag}]`}</div>
                )}
                <div
                  className={clsx(classes.customName)}
                  title={`${customName ?? ''} ${labelCustom ?? ''}`}
                >
                  {customName} {labelCustom}
                </div>
              </div>

              <div className="flex items-center ml-auto gap-[2px]">
                {locked && <i className={clsx(PrimeIcons.LOCK, 'text-[0.45rem] font-bold')} />}
                {hubs.includes(solar_system_id.toString()) && (
                  <i className={clsx(PrimeIcons.MAP_MARKER, 'text-[0.45rem] font-bold')} />
                )}
                {charactersInSystem.length > 0 && (
                  <div
                    className={clsx(
                      classes.localCounter,
                      'flex gap-[2px]'
                    )}
                  >
                    <span className="font-sans text-[0.65rem]">{charactersInSystem.length}</span>
                  </div>
                )}
              </div>
            </div>
          </>
        )}
      </div>

      {visible && isShowUnsplashedSignatures && (
        <div className={classes.Unsplashed}>
          {unsplashedLeft.map(x => (
            <UnsplashedSignature key={x.sig_id} signature={x} />
          ))}
        </div>
      )}
      {visible && isShowUnsplashedSignatures && (
        <div className={clsx(classes.Unsplashed, classes['Unsplashed--right'])}>
          {unsplashedRight.map(x => (
            <UnsplashedSignature key={x.sig_id} signature={x} />
          ))}
        </div>
      )}

      <div onMouseDownCapture={dbClick} className={classes.Handlers}>
      <Handle
          type="target"
          position={Position.Bottom}
          style={{
            width: '100%',
            height: '100%',
            background: 'none',
            cursor: 'cell',
            pointerEvents: dropHandler,
            opacity: 0,
            borderRadius: 0 }}
          id="whole-node-target"
        />
        <Handle
          type="source"
          className={clsx(classes.Handle, classes.HandleTop, {
            [classes.selected]: selected,
            [classes.Tick]: isThickConnections,
          })}
          style={{
            width: '100%',
            height: '55%',
            background: 'none',
            cursor: 'cell',
            opacity: 0,
            borderRadius: 0,
            visibility: showHandlers ? 'visible' : 'hidden',}}
          position={Position.Top}
          id="a"
        />
        <Handle
          type="source"
          className={clsx(classes.Handle, classes.HandleRight, {
            [classes.selected]: selected,
            [classes.Tick]: isThickConnections,
          })}
          style={{ visibility: showHandlers ? 'visible' : 'hidden', cursor: 'cell',  zIndex: 10  }}
          position={Position.Right}
          id="b"
        />
        <Handle
          type="source"
          className={clsx(classes.Handle, classes.HandleBottom, {
            [classes.selected]: selected,
            [classes.Tick]: isThickConnections,
          })}
          style={{ visibility: 'hidden', cursor: 'cell' }}
          position={Position.Bottom}
          id="c"
        />
        <Handle
          type="source"
          className={clsx(classes.Handle, classes.HandleLeft, {
            [classes.selected]: selected,
            [classes.Tick]: isThickConnections,
          })}
          style={{ visibility: showHandlers ? 'visible' : 'hidden', cursor: 'cell',  zIndex: 10  }}
          position={Position.Left}
          id="d"
        />
      </div>
    </>
  );
});
