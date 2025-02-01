import { useEffect, useState } from 'react';
import { BackgroundVariant } from 'reactflow';

export function useBackgroundVars(themeName?: string) {
  const [variant, setVariant] = useState<BackgroundVariant>(BackgroundVariant.Dots);
  const [gap, setGap] = useState<number>(16);
  const [size, setSize] = useState<number>(1);
  const [color, setColor] = useState('#81818b');
  const [snapSize, setSnapSize] = useState<number>(25);

  useEffect(() => {
    // match any element whose entire `class` attribute ends with "-theme"
    let themeEl = document.querySelector('[class$="-theme"]');

    // If none is found, fall back to the <html> element
    if (!themeEl) {
      themeEl = document.documentElement;
    }

    const style = getComputedStyle(themeEl as HTMLElement);

    const rawVariant = style.getPropertyValue('--rf-bg-variant').replace(/['"]/g, '').trim().toLowerCase();
    let finalVariant: BackgroundVariant = BackgroundVariant.Dots;

    if (rawVariant === 'lines') {
      finalVariant = BackgroundVariant.Lines;
    } else if (rawVariant === 'cross') {
      finalVariant = BackgroundVariant.Cross;
    }

    const cssVarGap = style.getPropertyValue('--rf-bg-gap');
    const cssVarSize = style.getPropertyValue('--rf-bg-size');
    const cssVarSnapSize = style.getPropertyValue('--rf-snap-size');
    const cssColor = style.getPropertyValue('--rf-bg-pattern-color');

    const gapNum = parseInt(cssVarGap, 10) || 16;
    const sizeNum = parseInt(cssVarSize, 10) || 1;
    const snapSize = parseInt(cssVarSnapSize, 10) || 25; //react-flow default

    setVariant(finalVariant);
    setGap(gapNum);
    setSize(sizeNum);
    setColor(cssColor);
    setSnapSize(snapSize);
  }, [themeName]);

  return { variant, gap, size, color, snapSize };
}
