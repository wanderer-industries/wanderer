import { memo } from 'react';
import { Handle, Position } from 'reactflow';
import clsx from 'clsx';

import classes from './SolarSystemNodeDefault.module.scss'; 
import { PrimeIcons } from 'primereact/api';

import { useSolarSystemNode } from '../../hooks/useSolarSystemNode';

import {
  MARKER_BOOKMARK_BG_STYLES,
  STATUS_CLASSES,
  EFFECT_BACKGROUND_STYLES,
} from '@/hooks/Mapper/components/map/constants';
import { WormholeClassComp } from '@/hooks/Mapper/components/map/components/WormholeClassComp';
import { UnsplashedSignature } from '@/hooks/Mapper/components/map/components/UnsplashedSignature';


export const SolarSystemNodeDefault = memo((props) => {
  const nodeVars = useSolarSystemNode(props);

  return (
    <>
      {nodeVars.visible && (
        <div className={classes.Bookmarks}>
          {nodeVars.labelCustom !== '' && (
            <div className={clsx(classes.Bookmark, MARKER_BOOKMARK_BG_STYLES.custom)}>
              <span className="[text-shadow:_0_1px_0_rgb(0_0_0_/_40%)] ">
                {nodeVars.labelCustom}
              </span>
            </div>
          )}

          {nodeVars.isShattered && (
            <div className={clsx(classes.Bookmark, MARKER_BOOKMARK_BG_STYLES.shattered)}>
              <span className={clsx('pi pi-chart-pie', classes.icon)} />
            </div>
          )}

          {nodeVars.killsCount && (
            <div
              className={clsx(
                classes.Bookmark,
                MARKER_BOOKMARK_BG_STYLES[nodeVars.killsActivityType!]
              )}
            >
              <div className={clsx(classes.BookmarkWithIcon)}>
                <span className={clsx(PrimeIcons.BOLT, classes.icon)} />
                <span className={clsx(classes.text)}>{nodeVars.killsCount}</span>
              </div>
            </div>
          )}

          {nodeVars.labelsInfo.map(x => (
            <div
              key={x.id}
              className={clsx(classes.Bookmark, MARKER_BOOKMARK_BG_STYLES[x.id])}
            >
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
          { [classes.selected]: nodeVars.selected },
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
                <div className={clsx(classes.TagTitle, 'text-sky-400 font-medium')}>
                  {nodeVars.tag}
                </div>
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
                    <WormholeClassComp key={whClass} id={whClass} />
                  ))}
                </div>
              )}

              {nodeVars.effectName !== null && nodeVars.isWormhole && (
                <div
                  className={clsx(
                    classes.effect,
                    EFFECT_BACKGROUND_STYLES[nodeVars.effectName],
                  )}
                />
              )}
            </div>

            <div className={clsx(classes.BottomRow, 'flex items-center justify-between')}>
              {nodeVars.customName && (
                <div className="[text-shadow:_0_1px_0_rgb(0_0_0_/_40%)] text-blue-300 whitespace-nowrap overflow-hidden text-ellipsis mr-0.5">
                  {nodeVars.customName}
                </div>
              )}

              {!nodeVars.isWormhole && !nodeVars.customName && (
                <div
                  className="[text-shadow:_0_1px_0_rgb(0_0_0_/_40%)] text-stone-300 whitespace-nowrap overflow-hidden text-ellipsis mr-0.5"
                >
                  {nodeVars.regionName}
                </div>
              )}

              {nodeVars.isWormhole && !nodeVars.customName && <div />}

              <div className="flex items-center justify-end">
                <div className="flex gap-1 items-center">
                  {nodeVars.locked && (
                    <i
                      className={PrimeIcons.LOCK}
                      style={{ fontSize: '0.45rem', fontWeight: 'bold' }}
                    />
                  )}

                  {nodeVars.hubs.includes(nodeVars.solarSystemId.toString()) && (
                    <i
                      className={PrimeIcons.MAP_MARKER}
                      style={{ fontSize: '0.45rem', fontWeight: 'bold' }}
                    />
                  )}

                  {nodeVars.charactersInSystem.length > 0 && (
                    <div
                      className={clsx(classes.localCounter, {
                        ['text-amber-300']: nodeVars.hasUserCharacters,
                      })}
                    >
                      <i className="pi pi-users" style={{ fontSize: '0.50rem' }} />
                      <span className="font-sans">
                        {nodeVars.charactersInSystem.length}
                      </span>
                    </div>
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
    </>
  );
});
