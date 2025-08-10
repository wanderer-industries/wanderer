import { useCallback, useRef, useState } from 'react';

export const useConfirmPopup = () => {
  const cfRef = useRef<HTMLElement>();
  const [cfVisible, setCfVisible] = useState(false);
  const cfShow = useCallback(() => setCfVisible(true), []);
  const cfHide = useCallback(() => setCfVisible(false), []);

  return { cfRef, cfVisible, cfShow, cfHide };
};
