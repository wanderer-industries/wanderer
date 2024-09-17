import { SystemSignature } from '@/hooks/Mapper/types';

// also we need detect changes, we need understand that sigs has states
// first state when kind is Cosmic Signature or Cosmic Anomaly and group is empty
// and we should detect it for ungrade sigs
export const getState = (_: string[], newSig: SystemSignature) => {
  let state = -1;
  if (!newSig.group || newSig.group === '') {
    state = 0;
  } else if (!!newSig.group && newSig.group !== '' && newSig.name === '') {
    state = 1;
  } else if (!!newSig.group && newSig.group !== '' && newSig.name !== '') {
    state = 2;
  }
  return state;
};
