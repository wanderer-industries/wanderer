import { Toast } from 'primereact/toast';

export const callToastWarn = (toast: Toast | null, msg: string, life = 3000) => {
  toast?.show({
    severity: 'warn',
    summary: 'Warning',
    detail: msg,
    life,
  });
};

export const callToastError = (toast: Toast | null, msg: string, life = 3000) => {
  toast?.show({
    severity: 'error',
    summary: 'Error',
    detail: msg,
    life,
  });
};

export const callToastSuccess = (toast: Toast | null, msg: string, life = 3000) => {
  toast?.show({
    severity: 'success',
    summary: 'Success',
    detail: msg,
    life,
  });
};
