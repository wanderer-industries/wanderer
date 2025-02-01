import { MenuItem } from 'primereact/menuitem';
import { PrimeIcons } from 'primereact/api';
import { useCallback, useRef } from 'react';
import { useMapRootState } from '@/hooks/Mapper/mapRootProvider';
import { SolarSystemRawType } from '@/hooks/Mapper/types';
import { getSystemById } from '@/hooks/Mapper/helpers';
import clsx from 'clsx';
import { GRADIENT_MENU_ACTIVE_CLASSES } from '@/hooks/Mapper/constants';
import { getCustomTagsForTheme, CustomTags } from '@/hooks/Mapper/components/map/helpers/getThemeBehavior';

/**
 * A helper that determines whether a system tag is “selected.”
 *
 * @param systemTag - The tag string.
 * @returns True if the tag is truthy.
 */
function isAnyTagSelected(systemTag?: string): boolean {
  return Boolean(systemTag);
}

/**
 * Builds the default theme menu.
 * This menu is organized into a sub-menu for letters and another for digits.
 *
 * @param system - The system object which may have an existing tag.
 * @param onSystemTag - Callback to update the system tag.
 * @param customTags - Custom tag definitions from the theme.
 * @returns A MenuItem representing the default theme tag menu.
 */
const buildDefaultThemeMenu = (
  system: SolarSystemRawType | undefined,
  onSystemTag: (val?: string) => void,
  customTags: CustomTags,
): MenuItem => {
  const tag = system?.tag || '';
  const isSelected = isAnyTagSelected(tag);
  const letters = customTags.letters ?? [];
  const digits = customTags.digits ?? [];
  const isSelectedLetters = letters.includes(tag ?? '');
  const isSelectedNumbers = digits.includes(tag ?? '');

  return {
    label: 'Tag',
    icon: PrimeIcons.HASHTAG,
    className: clsx({ [GRADIENT_MENU_ACTIVE_CLASSES]: isSelected }),
    items: [
      // "Clear" option if a tag is already set.
      ...(tag
        ? [
            {
              label: 'Clear',
              icon: PrimeIcons.BAN,
              command: () => onSystemTag(),
            },
          ]
        : []),
      {
        label: 'Letter',
        icon: PrimeIcons.TAGS,
        className: clsx({ [GRADIENT_MENU_ACTIVE_CLASSES]: isSelectedLetters }),
        items: letters.map(letter => ({
          label: letter,
          icon: PrimeIcons.TAG,
          command: () => onSystemTag(letter),
          className: clsx({ [GRADIENT_MENU_ACTIVE_CLASSES]: tag === letter }),
        })),
      },
      {
        label: 'Digit',
        icon: PrimeIcons.TAGS,
        className: clsx({ [GRADIENT_MENU_ACTIVE_CLASSES]: isSelectedNumbers }),
        items: digits.map(digit => ({
          label: digit,
          icon: PrimeIcons.TAG,
          command: () => onSystemTag(digit),
          className: clsx({ [GRADIENT_MENU_ACTIVE_CLASSES]: tag === digit }),
        })),
      },
    ],
  };
};

/**
 * Builds the pf theme menu.
 * This menu renders a top-level list of tags.
 *
 * @param system - The system object which may have an existing tag.
 * @param onSystemTag - Callback to update the system tag.
 * @param customTags - Custom tag definitions from the theme.
 * @returns A MenuItem representing the pf theme tag menu.
 */
const buildpfThemeMenu = (
  system: SolarSystemRawType | undefined,
  onSystemTag: (val?: string) => void,
  customTags: CustomTags,
): MenuItem => {
  const tag = system?.tag || '';
  const isSelected = isAnyTagSelected(tag);
  const pfTags = customTags.others ?? [];

  return {
    label: 'Occupied',
    icon: PrimeIcons.HASHTAG,
    className: clsx({ [GRADIENT_MENU_ACTIVE_CLASSES]: isSelected }),
    items: [
      ...(tag
        ? [
            {
              label: 'Clear',
              icon: PrimeIcons.BAN,
              command: () => onSystemTag(),
            },
          ]
        : []),
      ...pfTags.map(pfTag => ({
        label: pfTag,
        icon: PrimeIcons.TAG,
        command: () => onSystemTag(pfTag),
        className: clsx({ [GRADIENT_MENU_ACTIVE_CLASSES]: tag === pfTag }),
      })),
    ],
  };
};

type ThemeMenuBuilder = (
  system: SolarSystemRawType | undefined,
  onSystemTag: (val?: string) => void,
  customTags: CustomTags,
) => MenuItem;

// Map theme names to their corresponding builder functions.
const THEME_MENU_BUILDERS: Record<string, ThemeMenuBuilder> = {
  default: buildDefaultThemeMenu,
  pathfinder: buildpfThemeMenu,
};

/**
 * Custom hook to generate a tag menu for a given system based on the current theme.
 * It pulls the custom tags from the theme behavior file and falls back to default tags
 * if the theme doesn't have custom tags defined.
 *
 * @param systems - Array of available systems.
 * @param systemId - ID of the current system.
 * @param onSystemTag - Callback to update the system tag.
 * @returns A memoized function that returns a MenuItem based on the current theme.
 */
export const useTagMenu = (
  systems: SolarSystemRawType[],
  systemId: string | undefined,
  onSystemTag: (val?: string) => void,
): (() => MenuItem) => {
  const ref = useRef({ onSystemTag, systems, systemId });
  ref.current = { onSystemTag, systems, systemId };

  const { interfaceSettings } = useMapRootState();
  // Determine the current theme; default to 'default' if not set.
  const themeClass = interfaceSettings.theme ?? 'default';

  // Get custom tags for the current theme.
  const themeCustomTags = getCustomTagsForTheme(themeClass);
  // If the theme's custom tags are empty, fall back to the default theme's custom tags.
  const customTags: CustomTags =
    Object.keys(themeCustomTags).length > 0 ? themeCustomTags : getCustomTagsForTheme('default');

  return useCallback(() => {
    const { systems, systemId, onSystemTag } = ref.current;
    const system = systemId ? getSystemById(systems, systemId) : undefined;
    const builder = THEME_MENU_BUILDERS[themeClass] || THEME_MENU_BUILDERS.default;
    return builder(system, onSystemTag, customTags);
  }, [themeClass, customTags]);
};
