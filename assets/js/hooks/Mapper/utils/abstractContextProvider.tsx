import { createContext, ReactNode, useContext, useState } from 'react';

type ContextType<T> = {
  value: T;
  setValue: (newValue: T) => void;
};

export const createGenericContext = <T,>() => {
  const context = createContext<ContextType<T> | undefined>(undefined);

  const Provider = ({ children, initialValue }: { children: ReactNode; initialValue: T }) => {
    const [value, setValue] = useState<T>(initialValue);

    return <context.Provider value={{ value, setValue }}>{children}</context.Provider>;
  };

  const useContextValue = () => {
    const contextValue = useContext(context);
    if (!contextValue) {
      throw new Error('useContextValue must be used within a Provider');
    }
    return contextValue;
  };

  return { Provider, useContextValue };
};
