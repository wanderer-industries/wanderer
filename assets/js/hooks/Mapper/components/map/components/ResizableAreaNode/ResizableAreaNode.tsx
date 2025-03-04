import { NodeProps } from 'reactflow';
import { Rnd } from 'react-rnd';

export type ResizableAreaData = {
  width: number;
  height: number;
  bgColor: string;
  onResize: (nodeId: string, newWidth: number, newHeight: number) => void;
};

export const ResizableAreaNode = ({ id, data, selected, dragging, ...rest }: NodeProps<ResizableAreaData>) => {
  const { width = 200, height = 100, bgColor = 'rgba(255, 0, 0, 0.2)', onResize } = data;
  // eslint-disable-next-line no-console
  // console.log('JOipP', `ResizableAreaNode`, data);
  return (
    <div
      style={{
        position: 'relative',
        width,
        height,
        border: selected ? '2px solid red' : '2px dashed #999',
        backgroundColor: bgColor,
        pointerEvents: dragging ? 'none' : 'auto',
      }}
      {...rest}
    >
      <Rnd
        enableUserSelectHack={false}
        disableDragging={true}
        style={{ width: '100%', height: '100%' }}
        size={{ width, height }}
        onResizeStop={(e, direction, ref, delta, position) => {
          const newWidth = parseFloat(ref.style.width);
          const newHeight = parseFloat(ref.style.height);
          onResize?.(id, newWidth, newHeight);
        }}
        enableResizing={{
          top: true,
          right: true,
          bottom: true,
          left: true,
          topRight: true,
          bottomRight: true,
          bottomLeft: true,
          topLeft: true,
        }}
      >
        <div style={{ width: '100%', height: '100%', padding: 8 }}>
          Resizable Area: {width} x {height}
        </div>
      </Rnd>
    </div>
  );
};
