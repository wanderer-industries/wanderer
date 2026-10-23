import { Position, type Node } from 'reactflow';
import { isHorizontalLayoutDirection, ManagedLayoutDirection } from './map.types.ts';
import { getManagedHandlePositions } from './utils.ts';

const node = (id: string, x: number, y: number): Node => ({
  id,
  data: {},
  position: { x, y },
  positionAbsolute: { x, y },
  width: 130,
  height: 34,
});

describe('isHorizontalLayoutDirection', () => {
  test.each([
    [ManagedLayoutDirection.LeftRight, true],
    [ManagedLayoutDirection.RightLeft, true],
    [ManagedLayoutDirection.TopBottom, false],
    [ManagedLayoutDirection.BottomTop, false],
  ])('returns the expected result for %s', (direction, expected) => {
    expect(isHorizontalLayoutDirection(direction)).toBe(expected);
  });
});

describe('getManagedHandlePositions', () => {
  test('uses bottom and top center handles between TB levels regardless of horizontal offset', () => {
    expect(
      getManagedHandlePositions(node('parent', 500, 0), node('child', 0, 100), ManagedLayoutDirection.TopBottom),
    ).toEqual([Position.Bottom, Position.Top]);
  });

  test('uses side handles for a same-level TB connection', () => {
    expect(
      getManagedHandlePositions(node('left', 0, 100), node('right', 300, 100), ManagedLayoutDirection.TopBottom),
    ).toEqual([Position.Right, Position.Left]);
  });

  test('uses right and left center handles between LR levels regardless of vertical offset', () => {
    expect(
      getManagedHandlePositions(node('parent', 0, 500), node('child', 300, 0), ManagedLayoutDirection.LeftRight),
    ).toEqual([Position.Right, Position.Left]);
  });

  test('uses vertical handles for a same-level LR connection', () => {
    expect(
      getManagedHandlePositions(node('top', 300, 0), node('bottom', 300, 100), ManagedLayoutDirection.LeftRight),
    ).toEqual([Position.Bottom, Position.Top]);
  });
});
