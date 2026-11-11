// eslint-disable-next-line no-restricted-imports
import { Dialog, DialogProps } from 'primereact/dialog';

export type WdDialogProps = DialogProps;

export const WdDialog = (props: WdDialogProps) => {
  return <Dialog {...props} />;
};
