import { useRouteProvider } from '@/hooks/Mapper/components/mapInterface/widgets/RoutesWidget/RoutesProvider.tsx';
import { PrettySwitchbox } from '@/hooks/Mapper/components/mapRootContent/components/MapSettings/components';
import { WdButton } from '@/hooks/Mapper/components/ui-kit';
import { RoutesType } from '@/hooks/Mapper/mapRootProvider/types.ts';
import { Dialog } from 'primereact/dialog';
import { useCallback, useEffect, useRef, useState } from 'react';

interface RoutesSettingsDialog {
  visible: boolean;
  setVisible: (visible: boolean) => void;
}

type RoutesFlagsType = Omit<RoutesType, 'path_type' | 'avoid'>;

const checkboxes: { label: string; propName: keyof RoutesFlagsType }[] = [
  { label: 'Include Mass Crit', propName: 'include_mass_crit' },
  { label: 'Include EOL', propName: 'include_eol' },
  { label: 'Include Frigate', propName: 'include_frig' },
  { label: 'Include Cruise', propName: 'include_cruise' },
  { label: 'Include Thera connections', propName: 'include_thera' },
  { label: 'Avoid Wormholes', propName: 'avoid_wormholes' },
  { label: 'Avoid Pochven', propName: 'avoid_pochven' },
  { label: 'Avoid Edencom systems', propName: 'avoid_edencom' },
  { label: 'Avoid Triglavian systems', propName: 'avoid_triglavian' },
];

export const RoutesSettingsDialog = ({ visible, setVisible }: RoutesSettingsDialog) => {
  const { data, update } = useRouteProvider();

  const [, updateKey] = useState(0);

  const optionsRef = useRef(data);

  const currentData = useRef(data);
  currentData.current = data;

  const handleChangeEvent = useCallback(
    (propName: keyof RoutesType) => (event: boolean) => {
      optionsRef.current = { ...optionsRef.current, [propName]: event };
      updateKey(x => x + 1);
    },
    [],
  );

  const handleSave = useCallback(() => {
    update({ ...optionsRef.current });
    setVisible(false);
  }, [setVisible, update]);

  useEffect(() => {
    if (visible) {
      optionsRef.current = currentData.current;
      updateKey(x => x + 1);
    }
  }, [visible]);

  return (
    <Dialog
      header="Routes settings"
      visible={visible}
      draggable={false}
      style={{ width: '350px' }}
      onHide={() => {
        if (!visible) {
          return;
        }

        setVisible(false);
      }}
    >
      <div className="flex flex-col gap-3 p-2.5">
        <div className="flex flex-col gap-2 mb-2">
          {checkboxes.map(({ label, propName }) => (
            <PrettySwitchbox
              key={propName}
              label={label}
              checked={optionsRef.current[propName]}
              setChecked={handleChangeEvent(propName)}
            />
          ))}
        </div>

        <div className="flex gap-2 justify-end">
          <WdButton onClick={handleSave} outlined size="small" label="Apply"></WdButton>
        </div>
      </div>
    </Dialog>
  );
};
