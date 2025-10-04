import { memo } from 'react';
import { MapSolarSystemType } from '../../map.types';
import { Handle, NodeProps, Position } from 'reactflow';
import clsx from 'clsx';
import classes from './SolarSystemNodeTheme.module.scss';
import { PrimeIcons } from 'primereact/api';
import { useLocalCounter, useNodeKillsCount, useSolarSystemNode } from '../../hooks';
import {
  EFFECT_BACKGROUND_STYLES,
  MARKER_BOOKMARK_BG_STYLES,
  STATUS_CLASSES,
} from '@/hooks/Mapper/components/map/constants';
import { UnsplashedSignature } from '@/hooks/Mapper/components/map/components/UnsplashedSignature';
import { FixedTooltip, TooltipPosition, WdTooltipWrapper, WHClassView } from '@/hooks/Mapper/components/ui-kit';
import { TooltipSize } from '@/hooks/Mapper/components/ui-kit/WdTooltipWrapper/utils.ts';
import { LocalCounter } from '@/hooks/Mapper/components/map/components/LocalCounter';
import { KillsCounter } from '@/hooks/Mapper/components/map/components/KillsCounter';
import { useMapRootState } from '@/hooks/Mapper/mapRootProvider';
import { EffectRaw } from '@/hooks/Mapper/types/effect';

// let render = 0;
export const SolarSystemNodeTheme = memo((props: NodeProps<MapSolarSystemType>) => {
  const nodeVars = useSolarSystemNode(props);
  const { localCounterCharacters } = useLocalCounter(nodeVars);
  const { killsCount: localKillsCount, killsActivityType: localKillsActivityType } = useNodeKillsCount(
    nodeVars.solarSystemId,
  );

  const {
    data: { effects },
  } = useMapRootState();

  const prepareEffects = (effectsMap: Record<string, EffectRaw>, effectName: string, effectPower: number) => {
    const effect = effectsMap[effectName];
    if (!effect) return [] as { name: string; power: string; positive: boolean }[];
    const out: { name: string; power: string; positive: boolean }[] = [];
    effect.modifiers.map(mod => {
      const modPower = mod.power[effectPower - 1];
      out.push({ name: mod.name, power: modPower, positive: mod.positive });
    });
    out.sort((a, b) => (a.positive === b.positive ? 0 : a.positive ? -1 : 1));
    return out;
  };

  const targetClass = `wh-effect-node-${nodeVars.id}`;

  return (
    <>
      {nodeVars.visible && (
        <div className={classes.Bookmarks}>
          {nodeVars.isShattered && (
            <div className={clsx(classes.Bookmark, MARKER_BOOKMARK_BG_STYLES.shattered, '!pr-[2px]')}>
              <WdTooltipWrapper content="Shattered" position={TooltipPosition.top}>
                <span className={clsx('block w-[10px] h-[10px]', classes.ShatteredIcon)} />
              </WdTooltipWrapper>
            </div>
          )}

          {localKillsCount && localKillsCount > 0 && nodeVars.solarSystemId && localKillsActivityType && (
            <KillsCounter
              killsCount={localKillsCount}
              systemId={nodeVars.solarSystemId}
              size={TooltipSize.lg}
              killsActivityType={localKillsActivityType}
              className={clsx(classes.Bookmark, MARKER_BOOKMARK_BG_STYLES[localKillsActivityType])}
            >
              <div className={clsx(classes.BookmarkWithIcon)}>
                <span className={clsx(PrimeIcons.BOLT, classes.icon)} />
                <span className={clsx(classes.text)}>{localKillsCount}</span>
              </div>
            </KillsCounter>
          )}

          {nodeVars.labelCustom !== '' && (
            <div className={clsx(classes.Bookmark, MARKER_BOOKMARK_BG_STYLES.custom)}>
              <span className="[text-shadow:_0_1px_0_rgb(0_0_0_/_40%)]">{nodeVars.labelCustom}</span>
            </div>
          )}

          {nodeVars.labelsInfo.map(x => (
            <div key={x.id} className={clsx(classes.Bookmark, MARKER_BOOKMARK_BG_STYLES[x.id])}>
              {x.shortName}
            </div>
          ))}
        </div>
      )}

      <div
        className={clsx(
          classes.RootCustomNode,
          nodeVars.regionClass && classes[nodeVars.regionClass],
          nodeVars.status !== undefined ? classes[STATUS_CLASSES[nodeVars.status]] : '',
          {
            [classes.selected]: nodeVars.selected,
            [classes.rally]: nodeVars.isRally,
          },
        )}
        onMouseDownCapture={e => nodeVars.dbClick(e)}
      >
        {nodeVars.visible && (
          <>
            <div className={classes.HeadRow}>
              <div
                className={clsx(
                  classes.classTitle,
                  nodeVars.classTitleColor,
                  '[text-shadow:_0_1px_0_rgb(0_0_0_/_40%)]',
                )}
              >
                {nodeVars.classTitle ?? '-'}
              </div>

              {nodeVars.tag != null && nodeVars.tag !== '' && (
                <div className={clsx(classes.TagTitle)}>{nodeVars.tag}</div>
              )}

              <div
                className={clsx(
                  classes.classSystemName,
                  '[text-shadow:_0_1px_0_rgb(0_0_0_/_40%)] flex-grow overflow-hidden text-ellipsis whitespace-nowrap',
                )}
              >
                {nodeVars.systemName}
              </div>

              {nodeVars.isWormhole && (
                <div className={classes.statics}>
                  {nodeVars.sortedStatics.map(whClass => (
                    <WHClassView key={String(whClass)} whClassName={String(whClass)} hideWhClassName />
                  ))}
                </div>
              )}

              {nodeVars.effectName !== null && nodeVars.isWormhole && (
                <>
                  {nodeVars.effectPower ? (
                    <FixedTooltip
                      target={`.${targetClass}`}
                      position="right"
                      mouseTrack
                      mouseTrackLeft={20}
                      mouseTrackTop={30}
                    >
                      <div className={clsx('grid grid-cols-[1fr_auto] gap-x-4 gap-y-1 text-xs p-1')}>
                        {prepareEffects(effects, nodeVars.effectName, nodeVars.effectPower).map(
                          ({ name, power, positive }) => (
                            <>
                              <span key={name + '-n'}>{name}</span>
                              <span
                                key={name + '-p'}
                                className={clsx({ 'text-green-500': positive, 'text-red-500': !positive })}
                              >
                                {power}
                              </span>
                            </>
                          ),
                        )}
                      </div>
                    </FixedTooltip>
                  ) : null}
                  <div
                    className={clsx(
                      classes.effect,
                      EFFECT_BACKGROUND_STYLES[nodeVars.effectName],
                      targetClass,
                      'cursor-help',
                    )}
                  />
                </>
              )}
            </div>

            <div className={clsx(classes.BottomRow, 'flex items-center justify-between')}>
              {nodeVars.customName && (
                <div className="[text-shadow:_0_1px_0_rgb(0_0_0_/_40%)] whitespace-nowrap overflow-hidden text-ellipsis mr-0.5">
                  {nodeVars.customName}
                </div>
              )}

              {!nodeVars.isWormhole && !nodeVars.customName && (
                <div className="[text-shadow:_0_1px_0_rgb(0_0_0_/_40%)] whitespace-nowrap overflow-hidden text-ellipsis mr-0.5">
                  {nodeVars.regionName}
                </div>
              )}

              {nodeVars.isWormhole && !nodeVars.customName && <div />}

              <div className="flex items-center gap-1 justify-end">
                <div className={clsx('flex items-center gap-1')}>
                  {nodeVars.locked && <i className={clsx(PrimeIcons.LOCK, classes.lockIcon)} />}
                  {nodeVars.hubs.includes(nodeVars.solarSystemId) && (
                    <i className={clsx(PrimeIcons.MAP_MARKER, classes.mapMarker)} />
                  )}
                </div>

                <LocalCounter
                  hasUserCharacters={nodeVars.hasUserCharacters}
                  localCounterCharacters={localCounterCharacters}
                />
              </div>
            </div>
          </>
        )}
      </div>

      {nodeVars.visible && (
        <>
          {nodeVars.unsplashedLeft.length > 0 && (
            <div className={classes.Unsplashed}>
              {nodeVars.unsplashedLeft.map(sig => (
                <UnsplashedSignature key={sig.eve_id} signature={sig} />
              ))}
            </div>
          )}

          {nodeVars.unsplashedRight.length > 0 && (
            <div className={clsx(classes.Unsplashed, classes['Unsplashed--right'])}>
              {nodeVars.unsplashedRight.map(sig => (
                <UnsplashedSignature key={sig.eve_id} signature={sig} />
              ))}
            </div>
          )}
        </>
      )}

      <div className={classes.Handlers}>
        <Handle
          type="source"
          className={clsx(classes.Handle, classes.HandleTop, {
            [classes.selected]: nodeVars.selected,
            [classes.Tick]: nodeVars.isThickConnections,
          })}
          style={{ visibility: nodeVars.showHandlers ? 'visible' : 'hidden' }}
          position={Position.Top}
          id="a"
        />
        <Handle
          type="source"
          className={clsx(classes.Handle, classes.HandleRight, {
            [classes.selected]: nodeVars.selected,
            [classes.Tick]: nodeVars.isThickConnections,
          })}
          style={{ visibility: nodeVars.showHandlers ? 'visible' : 'hidden' }}
          position={Position.Right}
          id="b"
        />
        <Handle
          type="source"
          className={clsx(classes.Handle, classes.HandleBottom, {
            [classes.selected]: nodeVars.selected,
            [classes.Tick]: nodeVars.isThickConnections,
          })}
          style={{ visibility: nodeVars.showHandlers ? 'visible' : 'hidden' }}
          position={Position.Bottom}
          id="c"
        />
        <Handle
          type="source"
          className={clsx(classes.Handle, classes.HandleLeft, {
            [classes.selected]: nodeVars.selected,
            [classes.Tick]: nodeVars.isThickConnections,
          })}
          style={{ visibility: nodeVars.showHandlers ? 'visible' : 'hidden' }}
          position={Position.Left}
          id="d"
        />
      </div>
    </>
  );
});

SolarSystemNodeTheme.displayName = 'SolarSystemNodeTheme';
