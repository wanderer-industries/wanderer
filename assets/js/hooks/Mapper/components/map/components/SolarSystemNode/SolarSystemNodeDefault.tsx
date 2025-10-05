import { memo } from 'react';
import { MapSolarSystemType } from '../../map.types';
import { Handle, NodeProps, Position } from 'reactflow';
import clsx from 'clsx';
import classes from './SolarSystemNodeDefault.module.scss';
import { PrimeIcons } from 'primereact/api';
import { useLocalCounter, useNodeKillsCount, useSolarSystemNode } from '../../hooks';
import {
  EFFECT_BACKGROUND_STYLES,
  MARKER_BOOKMARK_BG_STYLES,
  STATUS_CLASSES,
} from '@/hooks/Mapper/components/map/constants';
import { UnsplashedSignature } from '@/hooks/Mapper/components/map/components/UnsplashedSignature';
import { TooltipSize } from '@/hooks/Mapper/components/ui-kit/WdTooltipWrapper/utils.ts';
import { TooltipPosition, WdTooltipWrapper, WHClassView, EffectsTooltip } from '@/hooks/Mapper/components/ui-kit';
import { Tag } from 'primereact/tag';
import { LocalCounter } from '@/hooks/Mapper/components/map/components/LocalCounter';
import { KillsCounter } from '@/hooks/Mapper/components/map/components/KillsCounter';

// let render = 0;
export const SolarSystemNodeDefault = memo((props: NodeProps<MapSolarSystemType>) => {
  const nodeVars = useSolarSystemNode(props);
  const { localCounterCharacters } = useLocalCounter(nodeVars);
  const { killsCount: localKillsCount, killsActivityType: localKillsActivityType } = useNodeKillsCount(
    nodeVars.solarSystemId,
  );

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

          {localKillsCount != null && localKillsCount > 0 && nodeVars.solarSystemId && localKillsActivityType && (
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
          nodeVars.status !== undefined && classes[STATUS_CLASSES[nodeVars.status]],
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
                <Tag
                  value={nodeVars.tag}
                  severity="warning"
                  className="py-0 px-[2px] text-[9px] [&_.p-tag-value]:leading-[1.3]"
                ></Tag>
              )}

              <div
                className={clsx(
                  classes.classSystemName,
                  '[text-shadow:_0_1px_0_rgb(0_0_0_/_40%)] flex-grow overflow-hidden text-ellipsis whitespace-nowrap font-sans',
                )}
              >
                {nodeVars.systemName}
              </div>

              {nodeVars.isWormhole && (
                <div className={classes.statics}>
                  {nodeVars.sortedStatics.map(whClass => (
                    <WHClassView key={String(whClass)} whClassName={String(whClass)} hideWhClassName showRigRow />
                  ))}
                </div>
              )}

              {nodeVars.effectName !== null && nodeVars.isWormhole && nodeVars.effectPower && (
                <EffectsTooltip effectName={nodeVars.effectName} effectPower={nodeVars.effectPower}>
                  <div className={clsx(classes.effect, EFFECT_BACKGROUND_STYLES[nodeVars.effectName])} />
                </EffectsTooltip>
              )}
            </div>

            <div className={clsx(classes.BottomRow, 'flex items-center justify-between')}>
              {nodeVars.customName && (
                <div className="[text-shadow:_0_1px_0_rgb(0_0_0_/_40%)] text-blue-300 whitespace-nowrap overflow-hidden text-ellipsis mr-0.5">
                  {nodeVars.customName}
                </div>
              )}

              {!nodeVars.isWormhole && !nodeVars.customName && (
                <div className="[text-shadow:_0_1px_0_rgb(0_0_0_/_40%)] text-stone-300 whitespace-nowrap overflow-hidden text-ellipsis mr-0.5">
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

SolarSystemNodeDefault.displayName = 'SolarSystemNodeDefault';
