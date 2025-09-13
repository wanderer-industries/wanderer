import React, { createContext, forwardRef, useContext } from 'react';
import {
  RoutesImperativeHandle,
  RoutesProviderInnerProps,
  RoutesWidgetProps,
} from '@/hooks/Mapper/components/mapInterface/widgets/RoutesWidget/types.ts';

type MapProviderProps = {
  children: React.ReactNode;
} & RoutesWidgetProps;

const RoutesContext = createContext<RoutesProviderInnerProps>({
  update: () => {},
  // @ts-ignore
  data: {},
});

// INFO: this component have imperative handler but now it not using.
export const RoutesProvider = forwardRef<RoutesImperativeHandle, MapProviderProps>(
  ({ children, ...props } /*, ref*/) => {
    // useImperativeHandle(ref, () => ({}));

    return <RoutesContext.Provider value={{ ...props /*, loading, setLoading*/ }}>{children}</RoutesContext.Provider>;
  },
);
RoutesProvider.displayName = 'RoutesProvider';

export const useRouteProvider = () => {
  const context = useContext<RoutesProviderInnerProps>(RoutesContext);
  return context;
};
