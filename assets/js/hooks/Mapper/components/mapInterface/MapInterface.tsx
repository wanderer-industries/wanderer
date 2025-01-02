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
import { WindowManager, WindowProps } from '@/hooks/Mapper/components/ui-kit/WindowManager';
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

const DEFAULT: WindowProps[] = [
  {
    id: 'info',
    position: { x: 10, y: 10 },
    size: { width: 250, height: 200 },
    zIndex: 0,
    content: () => <SystemInfo />,
  },
  {
    id: 'signatures',
    position: { x: 10, y: 220 },
    size: { width: 250, height: 300 },
    zIndex: 0,
    content: () => <SystemSignatures />,
  },
  {
    id: 'local',
    position: { x: 270, y: 10 },
    size: { width: 250, height: 510 },
    zIndex: 0,
    content: () => <LocalCharacters />,
  },
  {
    id: 'routes',
    position: { x: 10, y: 530 },
    size: { width: 510, height: 200 },
    zIndex: 0,
    content: () => <RoutesWidget />,
  },
];

export const MapInterface = () => {
  return <WindowManager windows={DEFAULT} dragSelector=".react-grid-dragHandleExample" />;

  // const [items, setItems] = useState<WidgetGridItem[]>(restoreWindowsFromLS);
  //
  // return (
  //   <WidgetsGrid
  //     items={items}
  //     onChange={x => {
  //       saveWindowsToLS(x);
  //       setItems(x);
  //     }}
  //   />
  // );
};
