import { useMemo } from 'react';
import clsx from 'clsx';
import { WdTooltipWrapper } from '@/hooks/Mapper/components/ui-kit/WdTooltipWrapper';
import { TooltipPosition } from '@/hooks/Mapper/components/ui-kit/WdTooltip';
import { LocalCharactersList, CharItemProps } from '../../../mapInterface/widgets/LocalCharacters/components';
import { useLocalCharactersItemTemplate } from '../../../mapInterface/widgets/LocalCharacters/hooks/useLocalCharacters';

interface LocalCounterProps {
  localCounterCharacters: Array<CharItemProps>;
  classes: { [key: string]: string };
  hasUserCharacters: boolean;
  showIcon?: boolean;
  showShipName?: boolean;
}

export function LocalCounter({
  localCounterCharacters,
  hasUserCharacters,
  classes,
  showIcon = true,
  showShipName = false,
}: LocalCounterProps) {
  const itemTemplate = useLocalCharactersItemTemplate(showShipName);

  const pilotTooltipContent = useMemo(() => {
    return (
      <div
        style={{
          width: '300px',
          height: '200px',
          overflowX: 'hidden',
          overflowY: 'auto',
        }}
      >
        <LocalCharactersList items={localCounterCharacters} itemTemplate={itemTemplate} itemSize={26} />
      </div>
    );
  }, [localCounterCharacters, itemTemplate]);

  if (localCounterCharacters.length === 0) {
    return null;
  }

  return (
    <div className={classes.LocalCounterLayer} style={{ zIndex: 9999 }}>
      <WdTooltipWrapper
        // @ts-ignore
        content={pilotTooltipContent}
        position={TooltipPosition.right}
        offset={8}
      >
        <div
          className={clsx(classes.localCounter, {
            [classes.hasUserCharacters]: hasUserCharacters,
          })}
        >
          {showIcon && <i className="pi pi-users" style={{ fontSize: '0.50rem' }} />}
          <span>{localCounterCharacters.length}</span>
        </div>
      </WdTooltipWrapper>
    </div>
  );
}
