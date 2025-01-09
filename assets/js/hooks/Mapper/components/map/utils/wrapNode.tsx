// wrapNode.ts
import { NodeProps } from 'reactflow';
import { SolarSystemNodeProps } from '../components/SolarSystemNode';

export function wrapNode<T>(
  SolarSystemNode: React.FC<SolarSystemNodeProps<T>>
): React.FC<NodeProps<T>> {
  return function NodeAdapter(props) {
    return <SolarSystemNode {...props} />;
  };
}
