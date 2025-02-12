import { useMemo } from 'react';
import clsx from 'clsx';
import { WdTooltipWrapper } from '@/hooks/Mapper/components/ui-kit/WdTooltipWrapper';
import { TooltipPosition } from '@/hooks/Mapper/components/ui-kit/WdTooltip';
import { CharItemProps, LocalCharactersList } from '../../../mapInterface/widgets/LocalCharacters/components';
import { useLocalCharactersItemTemplate } from '../../../mapInterface/widgets/LocalCharacters/hooks/useLocalCharacters';
import { useLocalCharacterWidgetSettings } from '../../../mapInterface/widgets/LocalCharacters/hooks/useLocalWidgetSettings';
import classes from './SolarSystemLocalCounter.module.scss';
import { AvailableThemes } from '@/hooks/Mapper/mapRootProvider';
import { useTheme } from '@/hooks/Mapper/hooks/useTheme.ts';

interface LocalCounterProps {
  localCounterCharacters: Array<CharItemProps>;
  hasUserCharacters: boolean;
  showIcon?: boolean;
}

export const LocalCounter = ({ localCounterCharacters, hasUserCharacters, showIcon = true }: LocalCounterProps) => {
  const [settings] = useLocalCharacterWidgetSettings();
  const itemTemplate = useLocalCharactersItemTemplate(settings.showShipName);
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
      className={clsx(classes.TooltipActive, {
        [classes.Pathfinder]: theme === AvailableThemes.pathfinder,
      })}
    >
      <WdTooltipWrapper content={pilotTooltipContent} position={TooltipPosition.right} offset={0} interactive={true}>
        <div className={clsx(classes.hoverTarget)}>
          <div
            className={clsx(classes.localCounter, {
              [classes.hasUserCharacters]: hasUserCharacters,
            })}
          >
            {showIcon && <i className="pi pi-users" />}
            <span>{localCounterCharacters.length}</span>
          </div>
        </div>
      </WdTooltipWrapper>
    </div>
  );
};
