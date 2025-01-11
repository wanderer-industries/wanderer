import React from 'react';

export type WindowProps = {
  id: string | number;
  content: (w: WindowProps) => React.ReactNode;
  position: { x: number; y: number };
  size: { width: number; height: number };
  zIndex: number;
  visible?: boolean;
};
