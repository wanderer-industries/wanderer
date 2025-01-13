import { SolarSystemNodeDefault, SolarSystemNodeTheme } from '../components/SolarSystemNode';
import type { NodeProps } from 'reactflow';
import type { ComponentType } from 'react';
import { MapSolarSystemType } from '../map.types';
import { ConnectionMode } from 'reactflow';

export type SolarSystemNodeComponent = ComponentType<NodeProps<MapSolarSystemType>>;

interface ThemeBehavior {
  isPanAndDrag: boolean;
  nodeComponent: SolarSystemNodeComponent;
  connectionMode: ConnectionMode;
}

const THEME_BEHAVIORS: {
  [key: string]: ThemeBehavior;
} = {
  default: {
    isPanAndDrag: false,
    nodeComponent: SolarSystemNodeDefault,
    connectionMode: ConnectionMode.Loose,
  },
  pathfinder: {
    isPanAndDrag: true,
    nodeComponent: SolarSystemNodeTheme,
    connectionMode: ConnectionMode.Loose,
  },
};

export function getBehaviorForTheme(themeName: string) {
  return THEME_BEHAVIORS[themeName] ?? THEME_BEHAVIORS.default;
}
