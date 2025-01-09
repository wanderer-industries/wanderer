import 'react-grid-layout/css/styles.css';
import 'react-resizable/css/styles.css';
import {
  LocalCharacters,
  RoutesWidget,
  SystemInfo,
  SystemSignatures,
} from '@/hooks/Mapper/components/mapInterface/widgets';
import { useState } from 'react';
import { SESSION_KEY } from '@/hooks/Mapper/constants.ts';
import { WindowManager } from '@/hooks/Mapper/components/ui-kit/WindowManager';
import { WindowProps } from '@/hooks/Mapper/components/ui-kit/WindowManager/types.ts';

const CURRENT_WINDOWS_VERSION = 2;

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

type WindowsLS = {
  windows: WindowProps[];
  version: number;
};

const saveWindowsToLS = (toSaveItems: WindowProps[]) => {
  // eslint-disable-next-line @typescript-eslint/no-unused-vars
  const out = toSaveItems.map(({ content, ...rest }) => rest);
  localStorage.setItem(SESSION_KEY.windows, JSON.stringify({ version: CURRENT_WINDOWS_VERSION, windows: out }));
};

const restoreWindowsFromLS = (): WindowProps[] => {
  // eslint-disable-next-line @typescript-eslint/no-unused-vars
  const raw = localStorage.getItem(SESSION_KEY.windows);
  if (!raw) {
    console.warn('No windows found in local storage!!');
    return DEFAULT;
  }

  const { version, windows } = JSON.parse(raw) as WindowsLS;
  if (!version || CURRENT_WINDOWS_VERSION > version) {
    return DEFAULT;
  }

  // eslint-disable-next-line no-debugger
  const out = (windows as Omit<WindowProps, 'content'>[])
    .filter(x => DEFAULT.find(def => def.id === x.id))
    .map(x => {
      const content = DEFAULT.find(def => def.id === x.id)?.content;
      return { ...x, content: content! };
    });

  return out;
};

export const MapInterface = () => {
  const [items, setItems] = useState<WindowProps[]>(restoreWindowsFromLS);

  return (
    <WindowManager
      windows={items}
      dragSelector=".react-grid-dragHandleExample"
      onChange={x => {
        saveWindowsToLS(x);
        setItems(x);
      }}
    />
  );
};
