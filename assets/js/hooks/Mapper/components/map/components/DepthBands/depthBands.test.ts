import { Node } from 'reactflow';
import { ManagedLayoutDirection } from '../../map.types.ts';
import { buildDepthBands, inferDepthBandsDirection } from './depthBands.ts';
import { buildRepeatedLabelPositions, getLabelRepeatCount } from './utils.ts';

const nodes: Node[] = [
  { id: 'root', data: {}, position: { x: 0, y: 100 }, width: 130, height: 34 },
  { id: 'child-a', data: {}, position: { x: 180, y: 40 }, width: 130, height: 34 },
  { id: 'child-b', data: {}, position: { x: 180, y: 160 }, width: 130, height: 34 },
  { id: 'leaf', data: {}, position: { x: 360, y: 100 }, width: 130, height: 34 },
];

describe('buildDepthBands', () => {
  it('groups nodes into LR depth columns and numbers them from left to right', () => {
    const bands = buildDepthBands(nodes, ManagedLayoutDirection.LeftRight);

    expect(bands.map(band => band.depth)).toEqual([0, 1, 2]);
    expect(bands[0].labelX).toBe(65);
    expect(bands[1].labelY).toBe(10);
    expect(bands[0].left + bands[0].width).toBeLessThan(bands[1].left);
  });

  it('numbers RL columns from right to left', () => {
    const bands = buildDepthBands(nodes, ManagedLayoutDirection.RightLeft);

    expect(bands.map(band => band.depth)).toEqual([2, 1, 0]);
  });

  it('builds top-to-bottom depth rows from zero', () => {
    const bands = buildDepthBands(nodes, ManagedLayoutDirection.TopBottom);

    expect(bands.map(band => band.depth)).toEqual([0, 1, 2]);
    expect(bands[0].top + bands[0].height).toBeLessThan(bands[1].top);
  });

  it('recognizes an already positioned horizontal graph', () => {
    const direction = inferDepthBandsDirection(nodes, [
      { id: 'root-child', source: 'root', target: 'child-a' },
      { id: 'child-leaf', source: 'child-a', target: 'leaf' },
    ]);

    expect(direction).toBe(ManagedLayoutDirection.LeftRight);
  });
});

describe('depth band labels', () => {
  test('uses separate repeat distances for horizontal and vertical layouts', () => {
    expect(getLabelRepeatCount(960, true)).toBe(6);
    expect(getLabelRepeatCount(960, false)).toBe(3);
  });

  test('pins every TB label to the bottom edge of its band', () => {
    const bands = buildDepthBands(nodes, ManagedLayoutDirection.TopBottom);

    for (const band of bands) {
      const [label] = buildRepeatedLabelPositions(band, ManagedLayoutDirection.TopBottom);
      expect(label.y).toBe(band.top + band.height - 12);
    }
  });

  test('pins every BT label to the top edge of its band', () => {
    const bands = buildDepthBands(nodes, ManagedLayoutDirection.BottomTop);

    for (const band of bands) {
      const [label] = buildRepeatedLabelPositions(band, ManagedLayoutDirection.BottomTop);
      expect(label.y).toBe(band.top + 12);
    }
  });
});
