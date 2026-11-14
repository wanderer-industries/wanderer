import { PrimeReactProvider } from 'primereact/api';
import { act } from 'react';
import { createRoot, type Root } from 'react-dom/client';
import { OutCommand } from '@/hooks/Mapper/types';
import { IntelSettings } from './IntelSettings';

jest.mock('@/hooks/Mapper/mapRootProvider', () => ({
  useMapRootState: () => ({ outCommand, data: { options: { intel_source_map_id: null } } }),
}));
jest.mock('@/hooks/Mapper/mapRootProvider/hooks/api', () => ({
  useMapCheckPermissions: () => true,
}));
jest.mock('@/hooks/Mapper/components/ui-kit', () => ({
  WdButton: jest.requireActual('primereact/button').Button,
}));
jest.mock('@/hooks/Mapper/helpers', () => ({ callToastError: jest.fn() }));

const outCommand = jest.fn(async ({ type, data }) => {
  if (type === OutCommand.getIntelSourceMaps) {
    return {
      maps: [
        { id: 'source-a', name: 'Source A', slug: 'source-a' },
        { id: 'source-b', name: 'Source B', slug: 'source-b' },
      ],
    };
  }
  if (type === OutCommand.setIntelSourceMap && data.intel_source_map_id === 'source-b') {
    return { success: false, error: 'source_is_subscriber' };
  }
  return { success: true, intel_source_map_id: data.intel_source_map_id };
});

const actEnvironment = globalThis as typeof globalThis & { IS_REACT_ACT_ENVIRONMENT?: boolean };
const previousActEnvironment = actEnvironment.IS_REACT_ACT_ENVIRONMENT;
let container: HTMLDivElement;
let root: Root;

beforeAll(() => {
  actEnvironment.IS_REACT_ACT_ENVIRONMENT = true;
});
afterAll(() => {
  actEnvironment.IS_REACT_ACT_ENVIRONMENT = previousActEnvironment;
});
beforeEach(async () => {
  container = document.createElement('div');
  document.body.appendChild(container);
  root = createRoot(container);
  await act(async () => {
    root.render(
      <PrimeReactProvider value={{ unstyled: true }}>
        <IntelSettings />
      </PrimeReactProvider>,
    );
  });
});
afterEach(async () => {
  await act(async () => root.unmount());
  container.remove();
});

const selectSource = async (label: string) => {
  const dropdown = container.querySelector<HTMLElement>('[data-pc-name="dropdown"]');
  if (!dropdown) throw new Error('Intel source dropdown is missing');
  await act(async () => dropdown.click());
  const option = document.querySelector<HTMLElement>(`[role="option"][aria-label="${label}"]`);
  if (!option) throw new Error(`Intel source option ${label} is missing`);
  await act(async () => option.click());
};

const selectedSource = () => container.querySelector('span[data-pc-section="input"]')?.textContent;
const clearDisabled = () => container.querySelector<HTMLButtonElement>('button[aria-label="Clear"]')?.disabled;

test('keeps the last accepted source after a later selection is refused', async () => {
  await selectSource('Source A');
  expect(selectedSource()).toBe('Source A');

  await selectSource('Source B');
  expect(selectedSource()).toBe('Source A');
  expect(clearDisabled()).toBe(false);
});

test('does not keep an optimistic source after two pending selections are refused', async () => {
  let refuseFirst = () => {};
  let refuseSecond = () => {};
  const refusal = { success: false, error: 'source_is_subscriber' };
  outCommand.mockImplementationOnce(
    () =>
      new Promise(resolve => {
        refuseFirst = () => resolve(refusal);
      }),
  );
  outCommand.mockImplementationOnce(
    () =>
      new Promise(resolve => {
        refuseSecond = () => resolve(refusal);
      }),
  );

  await selectSource('Source A');
  await selectSource('Source B');
  await act(async () => refuseFirst());
  await act(async () => refuseSecond());

  expect(selectedSource()).toBe('Select intel source map');
  expect(clearDisabled()).toBe(true);
});
