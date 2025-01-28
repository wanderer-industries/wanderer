import { SignatureCustomInfo } from '@/hooks/Mapper/types';

export const parseSignatureCustomInfo = (str: string | undefined): SignatureCustomInfo => {
  if (str == null || str === '') {
    return {};
  }

  return JSON.parse(str);
};
