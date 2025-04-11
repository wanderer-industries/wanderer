import React from 'react';

export interface WithChildren {
  children?: React.ReactNode;
}

export interface WithClassName {
  className?: string;
}

export type WithHTMLProps = React.HTMLAttributes<HTMLDivElement>;

export type IncomingEvent<T> = { data: T };
