import { SignatureCustomInfo } from '@/hooks/Mapper/types';

export const parseSignatureCustomInfo = (str: string | undefined): SignatureCustomInfo => {
  if (str == null || str === '') {
    return {};
  }

  try {
    return JSON.parse(str);
  } catch (e) {
    console.warn('Failed to parse signature custom_info', e);
    return {};
  }
};
