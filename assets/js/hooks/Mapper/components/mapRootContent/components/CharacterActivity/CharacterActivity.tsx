import { Dialog } from 'primereact/dialog';
import { Menu } from 'primereact/menu';
import { MenuItem } from 'primereact/menuitem';
import { useState, useCallback, useRef, useMemo } from 'react';
import { CharacterActivityContent } from '@/hooks/Mapper/components/mapRootContent/components/CharacterActivity/CharacterActivityContent.tsx';

interface CharacterActivityProps {
  visible: boolean;
  onHide: () => void;
}

const periodOptions = [
  { value: 30, label: '30 Days' },
  { value: 365, label: '1 Year' },
  { value: null, label: 'All Time' },
];

export const CharacterActivity = ({ visible, onHide }: CharacterActivityProps) => {
  const [selectedPeriod, setSelectedPeriod] = useState<number | null>(30);
  const menuRef = useRef<Menu>(null);

  const handlePeriodChange = useCallback((days: number | null) => {
    setSelectedPeriod(days);
  }, []);

  const menuItems: MenuItem[] = useMemo(
    () => [
      {
        label: 'Period',
        items: periodOptions.map(option => ({
          label: option.label,
          icon: selectedPeriod === option.value ? 'pi pi-check' : undefined,
          command: () => handlePeriodChange(option.value),
        })),
      },
    ],
    [selectedPeriod, handlePeriodChange],
  );

  const selectedPeriodLabel = useMemo(
    () => periodOptions.find(opt => opt.value === selectedPeriod)?.label || 'All Time',
    [selectedPeriod],
  );

  const headerIcons = (
    <>
      <button
        type="button"
        className="p-dialog-header-icon p-link"
        onClick={e => menuRef.current?.toggle(e)}
        aria-label="Filter options"
      >
        <span className="pi pi-bars" />
      </button>
      <Menu model={menuItems} popup ref={menuRef} />
    </>
  );

  return (
    <Dialog
      header={
        <div className="flex items-center gap-2">
          <span>Character Activity</span>
          <span className="text-xs text-stone-400">({selectedPeriodLabel})</span>
        </div>
      }
      visible={visible}
      className="w-[550px] max-h-[90vh]"
      onHide={onHide}
      dismissableMask
      contentClassName="p-0 h-full flex flex-col"
      icons={headerIcons}
    >
      <CharacterActivityContent selectedPeriod={selectedPeriod} />
    </Dialog>
  );
};
