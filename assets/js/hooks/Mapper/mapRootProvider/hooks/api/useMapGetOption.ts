import { useMemo } from 'react';
import { useMapRootState } from '@/hooks/Mapper/mapRootProvider';

export const useMapGetOption = (option: string) => {
  const {
    data: { options },
  } = useMapRootState();

  return useMemo(() => options[option], [option, options]);
};
