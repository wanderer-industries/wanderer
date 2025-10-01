import { SystemViewStandalone, WdButton, WHClassView, WHEffectView } from '@/hooks/Mapper/components/ui-kit';
import { useMapRootState } from '@/hooks/Mapper/mapRootProvider';
import { OutCommand, SearchSystemItem } from '@/hooks/Mapper/types';
import { AutoComplete } from 'primereact/autocomplete';
import { Dialog } from 'primereact/dialog';
import { IconField } from 'primereact/iconfield';
import { useCallback, useRef, useState } from 'react';
import classes from './AddSystemDialog.module.scss';

import { isWormholeSpace } from '@/hooks/Mapper/components/map/helpers/isWormholeSpace.ts';
import { sortWHClasses } from '@/hooks/Mapper/helpers';
import clsx from 'clsx';

export type SearchOnSubmitCallback = (item: SearchSystemItem) => void;

interface AddSystemDialogProps {
  title?: string;
  visible: boolean;
  setVisible: (visible: boolean) => void;
  onSubmit?: SearchOnSubmitCallback;
  excludedSystems?: number[];
}

export const AddSystemDialog = ({
  title = 'Add system',
  visible,
  setVisible,
  onSubmit,
  excludedSystems = [],
}: AddSystemDialogProps) => {
  const {
    outCommand,
    data: { wormholesData },
  } = useMapRootState();

  // TODO fix it
  const inputRef = useRef<any>();
  const onShow = useCallback(() => {
    inputRef.current?.focus();
  }, []);

  const [filteredItems, setFilteredItems] = useState<SearchSystemItem[]>([]);
  const [selectedItem, setSelectedItem] = useState<SearchSystemItem[] | null>(null);

  const searchItems = useCallback(
    async (event: { query: string }) => {
      if (event.query.length < 2) {
        setFilteredItems([]);
        return;
      }

      const query = event.query;

      if (query.length === 0) {
        setFilteredItems([]);
      } else {
        try {
          const result = await outCommand({
            type: OutCommand.searchSystems,
            data: {
              text: query,
            },
          });

          // TODO fix it
          let prepared = (result.systems as SearchSystemItem[]).sort((a, b) => {
            const amatch = a.label.indexOf(query);
            const bmatch = b.label.indexOf(query);
            return amatch - bmatch;
          });

          if (excludedSystems) {
            prepared = prepared.filter(x => !excludedSystems.includes(x.system_static_info.solar_system_id));
          }

          setFilteredItems(prepared);
        } catch (error) {
          console.error('Error fetching data:', error);
          setFilteredItems([]);
        }
      }
    },
    [excludedSystems, outCommand],
  );

  const ref = useRef({ onSubmit, selectedItem });
  ref.current = { onSubmit, selectedItem };

  const handleSubmit = useCallback(() => {
    const { onSubmit, selectedItem } = ref.current;
    setFilteredItems([]);
    setSelectedItem([]);

    if (!selectedItem) {
      setVisible(false);
      return;
    }

    onSubmit?.(selectedItem[0]);
    setVisible(false);
  }, [setVisible]);

  return (
    <Dialog
      header={title}
      visible={visible}
      draggable={false}
      style={{ width: '520px' }}
      onShow={onShow}
      onHide={() => {
        if (!visible) {
          return;
        }

        setVisible(false);
      }}
    >
      <form onSubmit={handleSubmit}>
        <div className="flex flex-col gap-3 px-1.5">
          <div className="flex flex-col gap-2 py-3.5">
            <div className="flex flex-col gap-1">
              <IconField>
                <AutoComplete
                  ref={inputRef}
                  multiple
                  showEmptyMessage
                  scrollHeight="300px"
                  value={selectedItem}
                  suggestions={filteredItems}
                  completeMethod={searchItems}
                  onChange={e => {
                    setSelectedItem(e.value.length < 2 ? e.value : [e.value[e.value.length - 1]]);
                  }}
                  emptyMessage="Not found any system..."
                  placeholder="Type here..."
                  field="label"
                  id="value"
                  className="w-full"
                  itemTemplate={(item: SearchSystemItem) => {
                    const { security, system_class, effect_power, effect_name, statics } = item.system_static_info;
                    const sortedStatics = sortWHClasses(wormholesData, statics);
                    const isWH = isWormholeSpace(system_class);

                    return (
                      <div className={clsx('flex gap-1.5', classes.SearchItem)}>
                        <SystemViewStandalone
                          security={security}
                          system_class={system_class}
                          solar_system_id={item.value}
                          class_title={item.class_title}
                          solar_system_name={item.label}
                          region_name={item.region_name}
                        />

                        {effect_name && isWH && (
                          <WHEffectView
                            effectName={effect_name}
                            effectPower={effect_power}
                            className={classes.SearchItemEffect}
                          />
                        )}

                        {isWH && (
                          <div className="flex gap-1 grow justify-between">
                            <div></div>
                            <div className="flex gap-1">
                              {sortedStatics.map(x => (
                                <WHClassView key={x} whClassName={x} />
                              ))}
                            </div>
                          </div>
                        )}
                      </div>
                    );
                  }}
                  selectedItemTemplate={(item: SearchSystemItem) => (
                    <SystemViewStandalone
                      security={item.system_static_info.security}
                      system_class={item.system_static_info.system_class}
                      solar_system_id={item.value}
                      class_title={item.class_title}
                      solar_system_name={item.label}
                      region_name={item.region_name}
                    />
                  )}
                />
              </IconField>

              <span className="text-[12px] text-stone-400 ml-1">*to search type at least 2 symbols.</span>
            </div>
          </div>

          <div className="flex gap-2 justify-end">
            <WdButton
              type="submit"
              onClick={handleSubmit}
              outlined
              disabled={!selectedItem || selectedItem.length !== 1}
              size="small"
              label="Submit"
            />
          </div>
        </div>
      </form>
    </Dialog>
  );
};
