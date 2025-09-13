import styles from './MapSettings.module.scss';

import { WdCheckbox } from '@/hooks/Mapper/components/ui-kit';

interface PrettySwitchboxProps {
  checked: boolean;
  setChecked: (checked: boolean) => void;
  label: string;
}

export const PrettySwitchbox = ({ checked, setChecked, label }: PrettySwitchboxProps) => {
  return (
    <label className="grid grid-cols-[auto_1fr_auto] items-center">
      <span className="text-[var(--gray-200)] text-[13px] select-none">{label}</span>
      <div className="border-b-2 border-dotted border-[#3f3f3f] h-px mx-3" />
      <div className={styles.smallInputSwitch}>
        <WdCheckbox size="m" label={''} value={checked} onChange={e => setChecked(e.checked ?? false)} />
      </div>
    </label>
  );
};
