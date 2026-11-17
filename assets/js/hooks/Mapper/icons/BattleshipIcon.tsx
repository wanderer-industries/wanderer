import { SvgIconProps } from '@/hooks/Mapper/components/ui-kit/SvgIconWrapper.tsx';

export const BattleshipIcon = ({ width = 16, height = 16, className, ...props }: SvgIconProps) => (
  <svg
    width={width}
    height={height}
    viewBox="0 0 16 16"
    fill="none"
    xmlns="http://www.w3.org/2000/svg"
    className={className}
    {...props}
  >
    <path
      d="M8 1.5L13.5 6.5V14.5L8 9.5L2.5 14.5V6.5L8 1.5Z"
      fill="#660000"
      stroke="#CC0000"
      strokeWidth="1.5"
      strokeLinejoin="round"
    />
  </svg>
);
