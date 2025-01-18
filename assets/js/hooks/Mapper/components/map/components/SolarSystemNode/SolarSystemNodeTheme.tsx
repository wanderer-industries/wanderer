import { memo } from 'react';
import { MapSolarSystemType } from '../../map.types';
import { Handle, Position, NodeProps } from 'reactflow';
import clsx from 'clsx';
import classes from './SolarSystemNodeTheme.module.scss';
import { PrimeIcons } from 'primereact/api';
import { useSolarSystemNode, useLocalCounter } from '../../hooks/useSolarSystemLogic';
import {
  MARKER_BOOKMARK_BG_STYLES,
  STATUS_CLASSES,
  EFFECT_BACKGROUND_STYLES,
} from '@/hooks/Mapper/components/map/constants';
import { WormholeClassComp } from '@/hooks/Mapper/components/map/components/WormholeClassComp';
import { UnsplashedSignature } from '@/hooks/Mapper/components/map/components/UnsplashedSignature';
import { LocalCounter } from './SolarSystemLocalCounter';
import { KillsCounter } from './SolarSystemKillsCounter';

export const SolarSystemNodeTheme = memo((props: NodeProps<MapSolarSystemType>) => {
  const nodeVars = useSolarSystemNode(props);
  const { localCounterCharacters, showShipName } = useLocalCounter(nodeVars);

  return (
    <>
      {nodeVars.visible && (
        <div className={classes.Bookmarks}>
          {nodeVars.labelCustom !== '' && (
            <div className={clsx(classes.Bookmark, MARKER_BOOKMARK_BG_STYLES.custom)}>
              <span className="[text-shadow:_0_1px_0_rgb(0_0_0_/_40%)] ">{nodeVars.labelCustom}</span>
            </div>
          )}

          {nodeVars.isShattered && (
            <div className={clsx(classes.Bookmark, MARKER_BOOKMARK_BG_STYLES.shattered)}>
              <span className={clsx('pi pi-chart-pie', classes.icon)} />
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
          classes[STATUS_CLASSES[nodeVars.status]],
          {
            [classes.selected]: nodeVars.selected,
          },
        )}
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
                    <WormholeClassComp key={whClass} id={whClass} />
                  ))}
                </div>
              )}

              {nodeVars.effectName !== null && nodeVars.isWormhole && (
                <div className={clsx(classes.effect, EFFECT_BACKGROUND_STYLES[nodeVars.effectName])} />
              )}
            </div>

            <div className={clsx(classes.BottomRow, 'flex items-center justify-between')}>
              {nodeVars.customName && (
                <div
                  className={clsx(
                    classes.CustomName,
                    '[text-shadow:_0_1px_0_rgb(0_0_0_/_40%)] whitespace-nowrap overflow-hidden text-ellipsis mr-0.5',
                  )}
                >
                  {nodeVars.customName}
                </div>
              )}

              {!nodeVars.isWormhole && !nodeVars.customName && (
                <div
                  className={clsx(
                    classes.RegionName,
                    '[text-shadow:_0_1px_0_rgb(0_0_0_/_40%)] whitespace-nowrap overflow-hidden text-ellipsis mr-0.5',
                  )}
                >
                  {nodeVars.regionName}
                </div>
              )}

              {nodeVars.isWormhole && !nodeVars.customName && <div />}

              <div className="flex items-center justify-end">
                <div className="flex gap-1 items-center">
                  {nodeVars.locked && (
                    <i
                      className={clsx(PrimeIcons.LOCK, classes.lockIcon, {
                        [classes.hasLocalCounter]: nodeVars.charactersInSystem.length > 0,
                      })}
                    />
                  )}

                  {nodeVars.hubs.includes(nodeVars.solarSystemId.toString()) && (
                    <i
                      className={clsx(PrimeIcons.MAP_MARKER, classes.mapMarker, {
                        [classes.hasLocalCounter]: nodeVars.charactersInSystem.length > 0,
                      })}
                    />
                  )}
                </div>
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
                <UnsplashedSignature key={sig.sig_id} signature={sig} />
              ))}
            </div>
          )}

          {nodeVars.unsplashedRight.length > 0 && (
            <div className={clsx(classes.Unsplashed, classes['Unsplashed--right'])}>
              {nodeVars.unsplashedRight.map(sig => (
                <UnsplashedSignature key={sig.sig_id} signature={sig} />
              ))}
            </div>
          )}
        </>
      )}

      <div onMouseDownCapture={nodeVars.dbClick} className={classes.Handlers}>
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
      <LocalCounter
        hasUserCharacters={nodeVars.hasUserCharacters}
        localCounterCharacters={localCounterCharacters}
        classes={classes}
        showShipName={showShipName}
      />
      {nodeVars.killsCount && nodeVars.killsCount > 0 && nodeVars.solarSystemId && (
        <KillsCounter
          killsCount={nodeVars.killsCount ?? 0}
          killsActivityType={nodeVars.killsActivityType ?? null}
          systemId={nodeVars.solarSystemId}
        />
      )}
    </>
  );
});

SolarSystemNodeTheme.displayName = 'SolarSystemNodeTheme';
