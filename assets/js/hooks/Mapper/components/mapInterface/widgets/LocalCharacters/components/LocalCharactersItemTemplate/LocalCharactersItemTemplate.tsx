import classes from './LocalCharactersItemTemplate.module.scss';
import clsx from 'clsx';
import { CharacterCard } from '@/hooks/Mapper/components/ui-kit';
import { CharItemProps } from '@/hooks/Mapper/components/mapInterface/widgets/LocalCharacters/components';
import { VirtualScrollerTemplateOptions } from 'primereact/virtualscroller';

export type LocalCharactersItemTemplateProps = { showShipName: boolean } & CharItemProps &
  VirtualScrollerTemplateOptions;

export const LocalCharactersItemTemplate = ({ showShipName, ...options }: LocalCharactersItemTemplateProps) => {
  return (
    <div
      className={clsx(
        classes.CharacterRow,
        'box-border flex items-center w-full whitespace-nowrap overflow-hidden text-ellipsis min-w-[0px]',
        'px-1',
        {
          'surface-hover': options.odd,
          'border-b border-gray-600 border-opacity-20': !options.last,
          'bg-green-500 hover:bg-green-700 transition duration-300 bg-opacity-10 hover:bg-opacity-10': options.online,
        },
      )}
      style={{ height: `${options.props.itemSize}px` }}
    >
      <CharacterCard showShipName={showShipName} showTicker {...options} />
    </div>
  );
};
