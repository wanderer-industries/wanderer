import { WindowProps } from '@/hooks/Mapper/components/ui-kit/WindowManager/types.ts';
import {
  CommentsWidget,
  LocalCharacters,
  SystemInfo,
  SystemSignatures,
  SystemStructures,
  WRoutesPublic,
  WRoutesUser,
  WSystemKills,
} from '@/hooks/Mapper/components/mapInterface/widgets';

export const CURRENT_WINDOWS_VERSION = 9;
export const WINDOWS_LOCAL_STORE_KEY = 'windows:settings:v2';

export enum WidgetsIds {
  info = 'info',
  signatures = 'signatures',
  local = 'local',
  routes = 'routes',
  structures = 'structures',
  kills = 'kills',
  comments = 'comments',
  userRoutes = 'userRoutes',
}

export const STORED_VISIBLE_WIDGETS_DEFAULT = [
  WidgetsIds.info,
  WidgetsIds.local,
  WidgetsIds.routes,
  WidgetsIds.signatures,
];

export const DEFAULT_WIDGETS: WindowProps[] = [
  {
    id: WidgetsIds.info,
    position: { x: 10, y: 10 },
    size: { width: 250, height: 200 },
    zIndex: 0,
    content: () => <SystemInfo />,
  },
  {
    id: WidgetsIds.signatures,
    position: { x: 10, y: 220 },
    size: { width: 250, height: 300 },
    zIndex: 0,
    content: () => <SystemSignatures />,
  },
  {
    id: WidgetsIds.local,
    position: { x: 270, y: 10 },
    size: { width: 250, height: 510 },
    zIndex: 0,
    content: () => <LocalCharacters />,
  },
  {
    id: WidgetsIds.routes,
    position: { x: 10, y: 530 },
    size: { width: 510, height: 200 },
    zIndex: 0,
    content: () => <WRoutesPublic />,
  },
  {
    id: WidgetsIds.userRoutes,
    position: { x: 10, y: 10 },
    size: { width: 510, height: 200 },
    zIndex: 0,
    content: () => <WRoutesUser />,
  },
  {
    id: WidgetsIds.structures,
    position: { x: 10, y: 730 },
    size: { width: 510, height: 200 },
    zIndex: 0,
    content: () => <SystemStructures />,
  },
  {
    id: WidgetsIds.kills,
    position: { x: 270, y: 730 },
    size: { width: 510, height: 200 },
    zIndex: 0,
    content: () => <WSystemKills />,
  },
  {
    id: WidgetsIds.comments,
    position: { x: 10, y: 10 },
    size: { width: 250, height: 300 },
    zIndex: 0,
    content: () => <CommentsWidget />,
  },
];

type WidgetsCheckboxesType = {
  id: WidgetsIds;
  label: string;
}[];

export const WIDGETS_CHECKBOXES_PROPS: WidgetsCheckboxesType = [
  {
    id: WidgetsIds.info,
    label: 'System Info',
  },
  {
    id: WidgetsIds.signatures,
    label: 'Signatures',
  },
  {
    id: WidgetsIds.local,
    label: 'Local',
  },
  {
    id: WidgetsIds.routes,
    label: 'Routes',
  },
  {
    id: WidgetsIds.userRoutes,
    label: 'User Routes',
  },
  {
    id: WidgetsIds.structures,
    label: 'Structures',
  },
  {
    id: WidgetsIds.kills,
    label: 'Kills',
  },
  {
    id: WidgetsIds.comments,
    label: 'Comments',
  },
];
