import { JumpSkillLevel } from '@/hooks/Mapper/mapRootProvider/types.ts';
import { SelectButton, SelectButtonPassThroughOptions } from 'primereact/selectbutton';
import clsx from 'clsx';
import { JUMP_SKILL_LEVEL_OPTIONS } from './constants.ts';

export type JumpSkillLevelAccent = 'sky' | 'emerald' | 'violet';

const ACTIVE_BUTTON_CLASSES: Record<JumpSkillLevelAccent, string> = {
  sky: '!border-sky-500/70 !bg-sky-500/25 !text-sky-200',
  emerald: '!border-emerald-500/70 !bg-emerald-500/25 !text-emerald-200',
  violet: '!border-violet-500/70 !bg-violet-500/25 !text-violet-200',
};

const LABEL_CLASSES: Record<JumpSkillLevelAccent, string> = {
  sky: 'text-sky-300',
  emerald: 'text-emerald-300',
  violet: 'text-violet-300',
};

const getLevelSelectPt = (accent: JumpSkillLevelAccent): SelectButtonPassThroughOptions => {
  return {
    root: { className: 'flex' },
    button: options => ({
      className: clsx(
        'h-8 min-w-0 flex-1 !px-0 !py-0 text-xs',
        options?.context.selected && ACTIVE_BUTTON_CLASSES[accent],
      ),
    }),
    label: { className: '!px-0 !py-0' },
  };
};

export interface JumpSkillLevelSelectProps {
  id: string;
  label: string;
  value: JumpSkillLevel;
  accent: JumpSkillLevelAccent;
  onChange(value: JumpSkillLevel): void;
}

export const JumpSkillLevelSelect = ({ id, label, value, accent, onChange }: JumpSkillLevelSelectProps) => {
  return (
    <label className="flex min-w-0 flex-col gap-1.5 text-xs text-stone-400" htmlFor={id}>
      <span className={clsx('font-medium', LABEL_CLASSES[accent])}>{label}</span>
      <SelectButton
        id={id}
        value={value}
        options={JUMP_SKILL_LEVEL_OPTIONS}
        allowEmpty={false}
        pt={getLevelSelectPt(accent)}
        onChange={event => onChange(event.value as JumpSkillLevel)}
      />
    </label>
  );
};
