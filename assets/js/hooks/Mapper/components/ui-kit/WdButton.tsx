// eslint-disable-next-line no-restricted-imports
import { Button, ButtonProps } from 'primereact/button';

export const WdButton = ({ type = 'button', ...props }: ButtonProps) => {
  // eslint-disable-next-line react/forbid-elements
  return <Button {...props} type={type} />;
};
