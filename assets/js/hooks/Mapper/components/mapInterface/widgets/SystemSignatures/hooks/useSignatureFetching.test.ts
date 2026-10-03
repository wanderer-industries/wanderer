import { act, createElement } from 'react';
import { createRoot, Root } from 'react-dom/client';
import { useMapRootState } from '@/hooks/Mapper/mapRootProvider';
import { SignatureGroup, SignatureKind, SystemSignature } from '@/hooks/Mapper/types';
import { OutCommand } from '@/hooks/Mapper/types/mapHandlers';
import { calculateBookmarkIndex } from '@/hooks/Mapper/helpers/bookmarkFormatHelper';
import { useSignatureFetching } from './useSignatureFetching';

jest.mock('@/hooks/Mapper/mapRootProvider', () => ({ useMapRootState: jest.fn() }));
jest.mock('../helpers', () => ({ getActualSigs: jest.fn(), prepareUpdatePayload: jest.fn() }));

const savedSignature: SystemSignature = {
  eve_id: 'OLD-100',
  kind: SignatureKind.CosmicSignature,
  group: SignatureGroup.Wormhole,
  name: '',
  type: '',
  custom_info: JSON.stringify({ bookmark_index: 1, bookmark_index_chained: '111' }),
};

type Store = { systemSignatures: Record<string, SystemSignature[]> };

let store: Store;
let root: Root;
let fetching: ReturnType<typeof useSignatureFetching>;
const outCommand = jest.fn();
const setSignatures = jest.fn();
const update = jest.fn((getNext: (prev: Store) => Partial<Store>) => {
  store = { ...store, ...getNext(store) };
});

const Widget = () => {
  fetching = useSignatureFetching({
    systemId: 'current',
    settings: {},
    signaturesRef: { current: [] },
    setSignatures,
  });
  return null;
};

beforeEach(async () => {
  jest.clearAllMocks();
  (globalThis as typeof globalThis & { IS_REACT_ACT_ENVIRONMENT: boolean }).IS_REACT_ACT_ENVIRONMENT = true;
  store = { systemSignatures: {} };
  outCommand.mockResolvedValue({ signatures: [savedSignature] });
  jest.mocked(useMapRootState).mockReturnValue({
    data: { characters: [] },
    outCommand,
    update,
  } as unknown as ReturnType<typeof useMapRootState>);
  root = createRoot(document.createElement('div'));
  await act(async () => {
    root.render(createElement(Widget));
  });
});

afterEach(async () => {
  await act(async () => {
    root.unmount();
  });
});

describe('fetched signatures used for bookmarks', () => {
  it('makes saved indices available to the bookmark calculation after reload', async () => {
    await act(async () => {
      await fetching.handleGetSignatures();
    });
    expect(outCommand).toHaveBeenCalledWith({ type: OutCommand.getSignatures, data: { system_id: 'current' } });
    expect(calculateBookmarkIndex(store.systemSignatures, 'current', '31000011', 'NEW-100').index).toBe(2);
    expect(setSignatures).toHaveBeenCalledTimes(1);
  });

  it('preserves signatures loaded in another system while the request was pending', async () => {
    let resolveRequest!: (value: { signatures: SystemSignature[] }) => void;
    outCommand.mockReturnValueOnce(
      new Promise(resolve => {
        resolveRequest = resolve;
      }),
    );
    const request = fetching.handleGetSignatures();
    store = { systemSignatures: { other: [savedSignature] } };
    await act(async () => {
      resolveRequest({ signatures: [savedSignature] });
      await request;
    });
    expect(store.systemSignatures).toEqual({ other: [savedSignature], current: [savedSignature] });
  });

  it('records an empty server response without discarding other systems', async () => {
    store = { systemSignatures: { other: [savedSignature] } };
    outCommand.mockResolvedValueOnce({ signatures: [] });
    await act(async () => {
      await fetching.handleGetSignatures();
    });
    expect(store.systemSignatures).toEqual({ other: [savedSignature], current: [] });
  });
});
