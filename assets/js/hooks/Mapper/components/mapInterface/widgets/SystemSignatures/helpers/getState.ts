import { UNKNOWN_SIGNATURE_NAME } from '@/hooks/Mapper/helpers';
import { SystemSignature } from '@/hooks/Mapper/types';

export const getState = (_: string[], newSig: SystemSignature) => {
  let state = -1;
  if (!newSig.group) {
    state = 0;
  } else if (!newSig.name || newSig.name === '' || newSig.name === UNKNOWN_SIGNATURE_NAME) {
    state = 1;
  } else if (newSig.name !== '') {
    state = 2;
  }
  return state;
};
