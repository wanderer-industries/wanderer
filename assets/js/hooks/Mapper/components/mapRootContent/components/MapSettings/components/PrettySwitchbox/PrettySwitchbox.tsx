import styles from './MapSettings.module.scss';
import { WdCheckbox } from '@/hooks/Mapper/components/ui-kit';

interface PrettySwitchboxProps {
  checked: boolean;
  setChecked: (checked: boolean) => void;
  label: string;
}

export const PrettySwitchbox = ({ checked, setChecked, label }: PrettySwitchboxProps) => {
  return (
    <div className={styles.CheckboxContainer}>
      <span>{label}</span>
      <div />
      <div className={styles.smallInputSwitch}>
        <WdCheckbox size="m" label={''} value={checked} onChange={e => setChecked(e.checked ?? false)} />
      </div>
    </div>
  );
};
