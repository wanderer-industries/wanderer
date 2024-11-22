import 'react-grid-layout/css/styles.css';
import 'react-resizable/css/styles.css';
import { WidgetGridItem, WidgetsGrid } from '@/hooks/Mapper/components/mapInterface/components';
import {
  LocalCharacters,
  RoutesWidget,
  SystemInfo,
  SystemSignatures,
} from '@/hooks/Mapper/components/mapInterface/widgets';
import { useState } from 'react';
import { SESSION_KEY } from '@/hooks/Mapper/constants.ts';
// import { debounce } from 'lodash/debounce';

const DEFAULT_WINDOWS = [
  {
    name: 'info',
    rightOffset: 5,
    width: 5,
    height: 4,
    item: () => <SystemInfo />,
  },
  {
    name: 'local',
    rightOffset: 5,
    topOffset: 4,
    width: 5,
    height: 4,
    item: () => <LocalCharacters />,
  },
  { name: 'signatures', width: 8, height: 4, topOffset: 8, rightOffset: 12, item: () => <SystemSignatures /> },
  {
    name: 'routes',
    rightOffset: 0,
    topOffset: 8,
    width: 5,
    height: 6,
    item: () => <RoutesWidget />,
  },
];

const saveWindowsToLS = (toSaveItems: WidgetGridItem[]) => {
  // eslint-disable-next-line @typescript-eslint/no-unused-vars
  const out = toSaveItems.map(({ item, ...rest }) => rest);
  localStorage.setItem(SESSION_KEY.windows, JSON.stringify(out));
};

const restoreWindowsFromLS = (): WidgetGridItem[] => {
  // eslint-disable-next-line @typescript-eslint/no-unused-vars
  const raw = localStorage.getItem(SESSION_KEY.windows);
  if (!raw) {
    console.warn('No windows found in local storage!!');
    return DEFAULT_WINDOWS;
  }

  // eslint-disable-next-line no-debugger
  const out = (JSON.parse(raw) as Omit<WidgetGridItem, 'item'>[])
    .filter(x => DEFAULT_WINDOWS.find(def => def.name === x.name))
    .map(x => {
      const windowItem = DEFAULT_WINDOWS.find(def => def.name === x.name)?.item;
      return { ...x, item: windowItem! };
    });

  return out;
};

export const MapInterface = () => {
  const [items, setItems] = useState<WidgetGridItem[]>(restoreWindowsFromLS);

  return (
    <WidgetsGrid
      items={items}
      onChange={x => {
        saveWindowsToLS(x);
        setItems(x);
      }}
    />
  );
};
