import { TooltipPosition, WdTooltipWrapper } from '@/hooks/Mapper/components/ui-kit';
import useLocalStorageState from 'use-local-storage-state';
import { useMapRootState } from '@/hooks/Mapper/mapRootProvider';

export const DebugComponent = () => {
  const { outCommand } = useMapRootState();

  const [record, setRecord] = useLocalStorageState<boolean>('record', {
    defaultValue: false,
  });

  // @ts-ignore
  const [recordsList] = useLocalStorageState<{ type; data }[]>('recordsList', {
    defaultValue: [],
  });

  const handleRunSavedEvents = () => {
    recordsList.forEach(record => outCommand(record));
  };

  return (
    <>
      <WdTooltipWrapper content="Run saved events" position={TooltipPosition.left}>
        <button
          className="btn bg-transparent text-gray-400 hover:text-white border-transparent hover:bg-transparent py-2 h-auto min-h-auto"
          type="button"
          onClick={handleRunSavedEvents}
          disabled={recordsList.length === 0 || record}
        >
          <i className="pi pi-forward"></i>
        </button>
      </WdTooltipWrapper>

      <WdTooltipWrapper content="Record" position={TooltipPosition.left}>
        <button
          className="btn bg-transparent text-gray-400 hover:text-white border-transparent hover:bg-transparent py-2 h-auto min-h-auto"
          type="button"
          onClick={() => setRecord(x => !x)}
        >
          {!record ? (
            <i className="pi pi-play-circle text-green-500"></i>
          ) : (
            <i className="pi pi-stop-circle text-red-500"></i>
          )}
        </button>
      </WdTooltipWrapper>
    </>
  );
};
