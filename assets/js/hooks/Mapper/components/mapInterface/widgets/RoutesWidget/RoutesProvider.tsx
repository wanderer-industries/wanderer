import React, { createContext, useContext } from 'react';
import { RoutesWidgetProps } from '@/hooks/Mapper/components/mapInterface/widgets/RoutesWidget/types.ts';

type MapProviderProps = {
  children: React.ReactNode;
} & RoutesWidgetProps;

const RoutesContext = createContext<RoutesWidgetProps>({
  update: () => {},
  // @ts-ignore
  data: {},
});

export const RoutesProvider: React.FC<MapProviderProps> = ({ children, ...props }) => {
  // TODO use it for save previous settings
  // useEffect(() => {
  //   const items = localStorage.getItem(SESSION_KEY.routes);
  //   if (items) {
  //     update(JSON.parse(items));
  //   }
  // }, [update]);

  return <RoutesContext.Provider value={props}>{children}</RoutesContext.Provider>;
};

export const useRouteProvider = () => {
  const context = useContext<RoutesWidgetProps>(RoutesContext);
  return context;
};
