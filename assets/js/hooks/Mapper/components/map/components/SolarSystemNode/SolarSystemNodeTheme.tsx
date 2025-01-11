import { memo } from 'react';
import { Handle, Position } from 'reactflow';
import clsx from 'clsx';

import classes from './SolarSystemNodeTheme.module.scss';
import { PrimeIcons } from 'primereact/api';

import { useSolarSystemNode } from '../../hooks/useSolarSystemNode';

import {
  MARKER_BOOKMARK_BG_STYLES,
  STATUS_CLASSES,
  EFFECT_BACKGROUND_STYLES,
} from '@/hooks/Mapper/components/map/constants';
import { WormholeClassComp } from '@/hooks/Mapper/components/map/components/WormholeClassComp';
import { UnsplashedSignature } from '@/hooks/Mapper/components/map/components/UnsplashedSignature';

export const SolarSystemNodeTheme = memo(props => {
  const {
    charactersInSystem,
    classTitle,
    classTitleColor,
    customName,
    effectName,
    hasUserCharacters,
    hubs,
    visible,
    labelCustom,
    labelsInfo,
    locked,
    isShattered,
    isThickConnections,
    isWormhole,
    killsCount,
    killsActivityType,
    regionClass,
    regionName,
    status,
    selected,
    tag,
    showHandlers,
    systemName,
    sortedStatics,
    solarSystemId,
    unsplashedLeft,
    unsplashedRight,
    dbClick: handleDbClick,
  } = useSolarSystemNode(props);

  return (
    <>
      {visible && (
        <div className={classes.Bookmarks}>
          {labelCustom !== '' && (
            <div className={clsx(classes.Bookmark, MARKER_BOOKMARK_BG_STYLES.custom)}>
              <span className="[text-shadow:_0_1px_0_rgb(0_0_0_/_40%)] ">{labelCustom}</span>
            </div>
          )}

          {isShattered && (
            <div className={clsx(classes.Bookmark, MARKER_BOOKMARK_BG_STYLES.shattered)}>
              <span className={clsx('pi pi-chart-pie', classes.icon)} />
            </div>
          )}

          {killsCount && (
            <div className={clsx(classes.Bookmark, MARKER_BOOKMARK_BG_STYLES[killsActivityType!])}>
              <div className={clsx(classes.BookmarkWithIcon)}>
                <span className={clsx(PrimeIcons.BOLT, classes.icon)} />
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
        className={clsx(classes.RootCustomNode, regionClass && classes[regionClass], classes[STATUS_CLASSES[status]], {
          [classes.selected]: selected,
        })}
      >
        {visible && (
          <>
            <div className={classes.HeadRow}>
              <div className={clsx(classes.classTitle, classTitleColor, '[text-shadow:_0_1px_0_rgb(0_0_0_/_40%)]')}>
                {classTitle ?? '-'}
              </div>

              {tag != null && tag !== '' && <div className={clsx(classes.TagTitle)}>{tag}</div>}

              <div
                className={clsx(
                  classes.classSystemName,
                  '[text-shadow:_0_1px_0_rgb(0_0_0_/_40%)] flex-grow overflow-hidden text-ellipsis whitespace-nowrap',
                )}
              >
                {systemName}
              </div>

              {isWormhole && (
                <div className={classes.statics}>
                  {sortedStatics.map(whClass => (
                    <WormholeClassComp key={whClass} id={whClass} />
                  ))}
                </div>
              )}

              {effectName !== null && isWormhole && (
                <div className={clsx(classes.effect, EFFECT_BACKGROUND_STYLES[effectName])} />
              )}
            </div>

            <div className={clsx(classes.BottomRow, 'flex items-center justify-between')}>
              {customName && (
                <div
                  className={clsx(
                    classes.CustomName,
                    '[text-shadow:_0_1px_0_rgb(0_0_0_/_40%)] whitespace-nowrap overflow-hidden text-ellipsis mr-0.5',
                  )}
                >
                  {customName}
                </div>
              )}

              {!isWormhole && !customName && (
                <div
                  className={clsx(
                    classes.RegionName,
                    '[text-shadow:_0_1px_0_rgb(0_0_0_/_40%)] whitespace-nowrap overflow-hidden text-ellipsis mr-0.5',
                  )}
                >
                  {regionName}
                </div>
              )}

              {isWormhole && !customName && <div />}

              <div className="flex items-center justify-end">
                <div className="flex gap-1 items-center">
                  {locked && <i className={PrimeIcons.LOCK} style={{ fontSize: '0.45rem', fontWeight: 'bold' }} />}

                  {hubs.includes(solarSystemId.toString()) && (
                    <i className={PrimeIcons.MAP_MARKER} style={{ fontSize: '0.45rem', fontWeight: 'bold' }} />
                  )}

                  {charactersInSystem.length > 0 && (
                    <div
                      className={clsx(classes.localCounter, {
                        [classes.hasUserCharacters]: hasUserCharacters,
                      })}
                    >
                      <i className="pi pi-users" style={{ fontSize: '0.50rem' }} />
                      <span className="font-sans">{charactersInSystem.length}</span>
                    </div>
                  )}
                </div>
              </div>
            </div>
          </>
        )}
      </div>

      {visible && (
        <>
          {unsplashedLeft.length > 0 && (
            <div className={classes.Unsplashed}>
              {unsplashedLeft.map(sig => (
                <UnsplashedSignature key={sig.sig_id} signature={sig} />
              ))}
            </div>
          )}

          {unsplashedRight.length > 0 && (
            <div className={clsx(classes.Unsplashed, classes['Unsplashed--right'])}>
              {unsplashedRight.map(sig => (
                <UnsplashedSignature key={sig.sig_id} signature={sig} />
              ))}
            </div>
          )}
        </>
      )}

      <div onMouseDownCapture={handleDbClick} className={classes.Handlers}>
        <Handle
          type="source"
          className={clsx(classes.Handle, classes.HandleTop, {
            [classes.selected]: selected,
            [classes.Tick]: isThickConnections,
          })}
          style={{ visibility: showHandlers ? 'visible' : 'hidden' }}
          position={Position.Top}
          id="a"
        />
        <Handle
          type="source"
          className={clsx(classes.Handle, classes.HandleRight, {
            [classes.selected]: selected,
            [classes.Tick]: isThickConnections,
          })}
          style={{ visibility: showHandlers ? 'visible' : 'hidden' }}
          position={Position.Right}
          id="b"
        />
        <Handle
          type="source"
          className={clsx(classes.Handle, classes.HandleBottom, {
            [classes.selected]: selected,
            [classes.Tick]: isThickConnections,
          })}
          style={{ visibility: showHandlers ? 'visible' : 'hidden' }}
          position={Position.Bottom}
          id="c"
        />
        <Handle
          type="source"
          className={clsx(classes.Handle, classes.HandleLeft, {
            [classes.selected]: selected,
            [classes.Tick]: isThickConnections,
          })}
          style={{ visibility: showHandlers ? 'visible' : 'hidden' }}
          position={Position.Left}
          id="d"
        />
      </div>
    </>
  );
});

SolarSystemNodeTheme.displayName = 'SolarSystemNodeTheme';
