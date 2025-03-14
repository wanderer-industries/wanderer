import classes from './WdTransition.module.scss';
import { CSSTransition, SwitchTransition } from 'react-transition-group';
import { WithChildren } from '@/hooks/Mapper/types/common.ts';
import { TransitionProps } from 'react-transition-group/Transition';

const FADE_CLASSES = {
  enter: classes.FadeEnter,
  enterActive: classes.FadeEnterActive,
  exit: classes.FadeExit,
  exitActive: classes.FadeExitActive,
};

export type WdTransitionProps = {
  active: boolean;
} & WithChildren &
  TransitionProps;

export const WdTransition = ({ active, children, ...transition }: WdTransitionProps) => {
  return (
    <SwitchTransition>
      <CSSTransition key={active ? 'one' : 'two'} {...transition} classNames={FADE_CLASSES}>
        {children}
      </CSSTransition>
    </SwitchTransition>
  );
};
