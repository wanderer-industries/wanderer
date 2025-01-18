import { useCallback } from 'react';
import { VirtualScrollerTemplateOptions } from 'primereact/virtualscroller';
import clsx from 'clsx';
import classes from './useLocalCharacters.module.scss';
import { CharacterCard } from '@/hooks/Mapper/components/ui-kit';
import { CharItemProps } from '../components';

export function useLocalCharactersItemTemplate(showShipName: boolean) {
  return useCallback(
    (char: CharItemProps, options: VirtualScrollerTemplateOptions) => {
      return (
        <div
          className={clsx(classes.CharacterRow, 'box-border flex items-center', {
            'surface-hover': options.odd,
            'border-b border-gray-600 border-opacity-20': !options.last,
            'bg-green-500 hover:bg-green-700 transition duration-300 bg-opacity-10 hover:bg-opacity-10': char.online,
          })}
          style={{
            height: `${options.props.itemSize}px`,
            whiteSpace: 'nowrap',
            overflow: 'hidden',
            textOverflow: 'ellipsis',
            minWidth: 0,
            width: '100%',
          }}
        >
          <CharacterCard showShipName={showShipName} {...char} />
        </div>
      );
    },
    [showShipName],
  );
}
