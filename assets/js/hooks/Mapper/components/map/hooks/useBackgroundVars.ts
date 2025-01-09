import { useEffect, useState } from 'react';
import { BackgroundVariant } from 'reactflow';


export function useBackgroundVars(themeName?: string) {
  const [variant, setVariant] = useState<BackgroundVariant>(BackgroundVariant.Dots);
  const [gap, setGap] = useState<number>(16);
  const [size, setSize] = useState<number>(1);
  const [color, setColor] = useState('#81818b')

  useEffect(() => { 
    let themeEl = document.querySelector('.pathfinder-theme, .default-theme');
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
    const cssColor = style.getPropertyValue('--rf-bg-pattern-color');

    const gapNum = parseInt(cssVarGap, 10) || 16;
    const sizeNum = parseInt(cssVarSize, 10) || 1;

    setVariant(finalVariant);
    setGap(gapNum);
    setSize(sizeNum);
    setColor(cssColor);

  }, [themeName]); 

  return { variant, gap, size, color };
}
