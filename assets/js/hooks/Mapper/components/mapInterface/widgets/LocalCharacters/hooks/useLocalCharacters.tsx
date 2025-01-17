import { useCallback } from 'react';
import { VirtualScrollerTemplateOptions } from 'primereact/virtualscroller';
import clsx from 'clsx';
import classes from './useLocalCharacters.module.scss';
import { CharacterCard } from '@/hooks/Mapper/components/ui-kit';
import { CharItemProps } from '../components';

/**
 * @param presentCharacters - characters to be shown
 */
export function useLocalCharactersItemTemplate() {
  return useCallback((char: CharItemProps, options: VirtualScrollerTemplateOptions) => {
    return (
      <div
        className={clsx(classes.CharacterRow, 'w-full box-border', {
          'surface-hover': options.odd,
          'border-b border-gray-600 border-opacity-20': !options.last,
          'bg-green-500 hover:bg-green-700 transition duration-300 bg-opacity-10 hover:bg-opacity-10': char.online,
        })}
        style={{ height: options.props.itemSize + 'px' }}
      >
        <CharacterCard showShipName {...char} />
      </div>
    );
  }, []);
}
