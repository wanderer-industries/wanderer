// eslint-disable-next-line no-restricted-imports
import { InputText, InputTextProps } from 'primereact/inputtext';

export type WdInputTextProps = InputTextProps;

export const WdInputText = (props: WdInputTextProps) => {
  return <InputText {...props} />;
};
