import classes from '@/hooks/Mapper/components/ui-kit/WdTooltipWrapper/WdTooltipWrapper.module.scss';

export enum TooltipSize {
  xs = 'xs',
  sm = 'sm',
  md = 'md',
  lg = 'lg',
}

export const sizeClass = (size: TooltipSize) => {
  switch (size) {
    case TooltipSize.xs:
      return classes.wdTooltipSizeXs;
    case TooltipSize.sm:
      return classes.wdTooltipSizeSm;
    case TooltipSize.md:
      return classes.wdTooltipSizeMd;
    case TooltipSize.lg:
      return classes.wdTooltipSizeLg;
    default:
      return undefined;
  }
};
