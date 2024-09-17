import React, { createContext, useContext, useEffect } from 'react';
import { ContextStoreDataUpdate, useContextStore } from '@/hooks/Mapper/utils';
import { SESSION_KEY } from '@/hooks/Mapper/constants.ts';

export type RoutesType = {
  path_type: 'shortest' | 'secure' | 'insecure';
  include_mass_crit: boolean;
  include_eol: boolean;
  include_frig: boolean;
  include_cruise: boolean;
  include_thera: boolean;
  avoid_wormholes: boolean;
  avoid_pochven: boolean;
  avoid_edencom: boolean;
  avoid_triglavian: boolean;
  avoid: number[];
};

interface MapProviderProps {
  children: React.ReactNode;
}

export const DEFAULT_SETTINGS: RoutesType = {
  path_type: 'shortest',
  include_mass_crit: true,
  include_eol: true,
  include_frig: true,
  include_cruise: true,
  include_thera: true,
  avoid_wormholes: false,
  avoid_pochven: false,
  avoid_edencom: false,
  avoid_triglavian: false,
  avoid: [],
};

export interface MapContextProps {
  update: ContextStoreDataUpdate<RoutesType>;
  data: RoutesType;
}

const RoutesContext = createContext<MapContextProps>({
  update: () => {},
  data: { ...DEFAULT_SETTINGS },
});

export const RoutesProvider: React.FC<MapProviderProps> = ({ children }) => {
  const { update, ref } = useContextStore<RoutesType>(
    { ...DEFAULT_SETTINGS },
    {
      onAfterAUpdate: values => {
        localStorage.setItem(SESSION_KEY.routes, JSON.stringify(values));
      },
    },
  );

  useEffect(() => {
    const items = localStorage.getItem(SESSION_KEY.routes);
    if (items) {
      update(JSON.parse(items));
    }
  }, [update]);

  return (
    <RoutesContext.Provider
      value={{
        update,
        data: ref,
      }}
    >
      {children}
    </RoutesContext.Provider>
  );
};

export const useRouteProvider = () => {
  const context = useContext<MapContextProps>(RoutesContext);
  return context;
};
