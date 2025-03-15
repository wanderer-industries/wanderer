%{
title: "How to Add a Custom Theme",
author: "Wanderer Community",
cover_image_uri: "/images/news/01-13-theme-swap/theme-selector.png",
tags: ~w(themes),
description: "",
}

---

# How to Add a Custom Theme

Adding a custom theme to your map is a great way to give it a unique look and feel. In this guide, we’ll walk you through the necessary steps to create and enable a brand-new theme, from updating the theme selector to creating custom SCSS files.

---

1. Add Your Theme to the Theme Selector


Open the file:

assets/js/hooks/Mapper/components/mapRootContent/components/MapSettings/MapSettings.tsx


In this file, you’ll find an array called `THEME_OPTIONS`. Simply add your new theme to this array, giving it both a `label` and a `value`. For example:

```ts
const THEME_OPTIONS = [
  { label: 'Default',    value: 'default' },
  { label: 'Pathfinder', value: 'pathfinder' },
  { label: 'YourTheme',  value: 'yourtheme' },
];
```

This ensures your new theme will appear in the theme selection menu.

---

 2. Create the SCSS File for Your Theme

Next, you’ll need to create a new SCSS file to define your theme’s custom styles. Navigate to:

```
assets/js/hooks/Mapper/components/map/styles
```

and add a new file. You can use `pathfinder-theme.scss` as a reference. The **filename must be in the format**:

```
yourthemename-theme.scss
```

> **Why the specific format?**  
> The system looks for theme files following this naming pattern. If you choose a different format, it will not load correctly.

# 2.1. Define Your CSS Variables

Inside your theme SCSS file, you can override the variables below to customize colors, backgrounds, patterns, text, and more. For example:

```scss
// yourtheme-theme.scss

:root {
  /* Main pane background color */
  --rf-bg-color: #222;
  --rf-soft-bg-color: #333;

  /* Background pattern settings */
  --rf-bg-variant: lines; 
  --rf-bg-gap: 10px;
  --rf-bg-size: 1px;
  --rf-bg-pattern-color: rgba(255, 255, 255, 0.15);

  /* Node (system) appearance */
  --rf-node-bg-color: #444;
  --rf-node-soft-bg-color: #555;
  --rf-node-font-family: "Roboto", sans-serif;
  --rf-text-color: #f5f5f5;
  --rf-region-name: #a3e4d7;
  --rf-custom-name: #d7bde2;
  --rf-tag-color: #e59866;
  --rf-has-user-character: #f9e79f;

  /* Eve-specific overrides */
  --eve-effect-nullsec: #ff0000;
  --eve-wh-type-color-C1: #aaffaa;
  /* ...etc... */
}
```

> **Tip:** Feel free to rename or add new custom variables as necessary, but keep in mind the defaults and naming conventions used throughout the existing code.

---

 3. Customize Node-Related Styles

If you want to override more specific aspects of the node styling, review the file:

```
assets/js/hooks/Mapper/components/map/components/SolarSystemNode/SolarSystemNodeTheme.module.scss
```

This file shows which variables are already set up for styling through CSS variables. If the element you want to style already has a variable reference, you can simply override that variable in your SCSS theme file.

---

 4. Update Theme Behavior (Optional)

Finally, if your theme requires special interactions, you can update the theme behavior in:

```
assets/js/hooks/Mapper/components/map/helpers/getThemeBehavior.ts
```

By default, some overrides are already set up. For example:

- `isPanAndDrag: true` sets left-click to select, and right-click to pan. (When `false`, it uses the default behavior)
- `nodeComponent: SolarSystemNodeTheme` specifies a special node component that uses theme CSS overrides -- you could also provide your own node component here
- `connectionMode: ConnectionMode.Loose` allows you to control how strict the connection handles are.

If your theme needs custom logic—like a different node component or a unique interaction pattern—this is where you’d implement it.

---

 Summary

1. **Add your theme** to `THEME_OPTIONS` in `MapSettings.tsx`.  
2. **Create a custom SCSS file** with the pattern `yourtheme-theme.scss` and override any relevant variables.  
3. **Check for additional styling** in `SolarSystemNodeTheme.module.scss` to see if there are more elements you’d like to override.  
4. (Optional) **Modify the theme behavior** in `getThemeBehavior.ts` if you want your theme to have unique interaction patterns or different default behaviors.

By following these steps, you’ll be able to quickly add your own themed experience to the map. If you need to make further changes (like adding new variables or hooking into different node components), just follow the same pattern and refer to existing examples in the codebase. Happy theming!

---

### Example of heavily customize node component and theme

![Faoble Theme]("/images/news/01-13-theme-swap/faoble-theme.png")

---

Fly safe,  
**The Wanderer Team**
