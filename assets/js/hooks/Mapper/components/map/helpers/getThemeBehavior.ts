import { SolarSystemNodeDefault, SolarSystemNodeTheme } from '../components/SolarSystemNode';
import type { NodeProps } from 'reactflow';
import type { ComponentType } from 'react';
import { MapSolarSystemType } from '../map.types';
import { ConnectionMode } from 'reactflow';

export type SolarSystemNodeComponent = ComponentType<NodeProps<MapSolarSystemType>>;

/**
 * CustomTags provides a structured way to define tag options per theme.
 * - For the default theme, we use "letters" and "digits".
 */
export interface CustomTags {
  letters?: string[];
  digits?: string[];
  others?: string[];
}

/**
 * ThemeBehavior defines the behavior for a given theme,
 * including the node component, pan-and-drag setting, connection mode,
 * and optionally, the custom tags.
 */
interface ThemeBehavior {
  isPanAndDrag: boolean;
  nodeComponent: SolarSystemNodeComponent;
  connectionMode: ConnectionMode;
  customTags?: CustomTags;
}

const THEME_BEHAVIORS: { [key: string]: ThemeBehavior } = {
  default: {
    isPanAndDrag: false,
    nodeComponent: SolarSystemNodeDefault,
    connectionMode: ConnectionMode.Loose,
    customTags: {
      letters: ['A', 'B', 'C', 'D', 'E', 'F', 'X', 'Y', 'Z'],
      digits: ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'],
    },
  },
  pathfinder: {
    isPanAndDrag: true,
    nodeComponent: SolarSystemNodeTheme,
    connectionMode: ConnectionMode.Loose,
    customTags: {
      others: ['1', '2', '3', '4', '5', '6', '7', '8', '10+', '20+'],
    },
  },
};

/**
 * @param themeName - The name of the theme.
 * @returns The ThemeBehavior object.
 */
export function getBehaviorForTheme(themeName: string): ThemeBehavior {
  return THEME_BEHAVIORS[themeName] ?? THEME_BEHAVIORS.default;
}

/**
 * @param themeName - The name of the theme.
 * @returns The CustomTags object for the theme, or an empty object if none are defined.
 */
export function getCustomTagsForTheme(themeName: string): CustomTags {
  return getBehaviorForTheme(themeName).customTags ?? {};
}
