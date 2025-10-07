import { useMemo } from 'react';
import clsx from 'clsx';
import { WdTooltipWrapper } from '@/hooks/Mapper/components/ui-kit/WdTooltipWrapper';
import { TooltipPosition } from '@/hooks/Mapper/components/ui-kit/WdTooltip';
import { CharItemProps, LocalCharactersList } from '../../../mapInterface/widgets/LocalCharacters/components';
import { useTheme } from '@/hooks/Mapper/hooks/useTheme.ts';
import { AvailableThemes } from '@/hooks/Mapper/mapRootProvider/types.ts';
import classes from './LocalCounter.module.scss';
import { useMapState } from '@/hooks/Mapper/components/map/MapProvider.tsx';
import { useLocalCharactersItemTemplate } from '@/hooks/Mapper/components/mapInterface/widgets/LocalCharacters/hooks/useLocalCharacters.tsx';

interface LocalCounterProps {
  localCounterCharacters: Array<CharItemProps>;
  hasUserCharacters: boolean;
  showIcon?: boolean;
  disableInteractive?: boolean;
  className?: string;
  contentClassName?: string;
}

export const LocalCounter = ({
  className,
  contentClassName,
  localCounterCharacters,
  hasUserCharacters,
  showIcon = true,
  disableInteractive,
}: LocalCounterProps) => {
  const {
    data: { localShowShipName },
  } = useMapState();
  const itemTemplate = useLocalCharactersItemTemplate(localShowShipName);
  const theme = useTheme();

  const pilotTooltipContent = useMemo(() => {
    return (
      <div
        style={{
          width: '100%',
          minWidth: '300px',
          overflow: 'hidden',
        }}
      >
        <LocalCharactersList items={localCounterCharacters} itemTemplate={itemTemplate} itemSize={26} autoSize={true} />
      </div>
    );
  }, [localCounterCharacters, itemTemplate]);

  if (localCounterCharacters.length === 0) {
    return null;
  }

  return (
    <div
      className={clsx(
        classes.TooltipActive,
        {
          [classes.Pathfinder]: theme === AvailableThemes.pathfinder,
        },
        className,
      )}
    >
      <WdTooltipWrapper
        content={pilotTooltipContent}
        position={TooltipPosition.right}
        offset={0}
        interactive={!disableInteractive}
        smallPaddings
      >
        <div className={clsx(classes.hoverTarget)}>
          <div
            className={clsx(
              classes.localCounter,
              {
                [classes.hasUserCharacters]: hasUserCharacters,
              },
              contentClassName,
            )}
          >
            {showIcon && <i className="pi pi-users" />}
            <span>{localCounterCharacters.length}</span>
          </div>
        </div>
      </WdTooltipWrapper>
    </div>
  );
};
