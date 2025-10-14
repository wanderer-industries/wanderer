import React, { createContext, useContext, useRef } from 'react';
import { Toast } from 'primereact/toast';
import type { ToastMessage } from 'primereact/toast';

interface ToastContextValue {
  toastRef: React.RefObject<Toast>;
  show: (message: ToastMessage | ToastMessage[]) => void;
}

const ToastContext = createContext<ToastContextValue | null>(null);

export const ToastProvider: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  const toastRef = useRef<Toast>(null);

  const show = (message: ToastMessage | ToastMessage[]) => {
    toastRef.current?.show(message);
  };

  return (
    <ToastContext.Provider value={{ toastRef, show }}>
      <Toast ref={toastRef} position="top-right" />
      {children}
    </ToastContext.Provider>
  );
};

export const useToast = (): ToastContextValue => {
  const context = useContext(ToastContext);
  if (!context) throw new Error('useToast must be used within a ToastProvider');
  return context;
};
