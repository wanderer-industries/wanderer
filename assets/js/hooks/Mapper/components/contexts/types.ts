import React from 'react';
import { Node } from 'reactflow';

export type WaypointSetContextHandlerProps = {
  charIds: string[];
  fromBeginning: boolean;
  clearWay: boolean;
  destination: string;
};
export type WaypointSetContextHandler = (props: WaypointSetContextHandlerProps) => void;
export type NodeSelectionMouseHandler = (event: React.MouseEvent<Element, MouseEvent>, nodes: Node[]) => void;
