import { useCallback } from 'react';
import { VirtualScrollerTemplateOptions } from 'primereact/virtualscroller';
import { CharItemProps, LocalCharactersItemTemplate } from '../components';

export function useLocalCharactersItemTemplate(showShipName: boolean) {
  return useCallback(
    (char: CharItemProps, options: VirtualScrollerTemplateOptions) => (
      <LocalCharactersItemTemplate {...char} {...options} showShipName={showShipName} />
    ),
    [showShipName],
  );
}
