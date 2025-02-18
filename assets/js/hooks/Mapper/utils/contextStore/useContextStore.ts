import { useCallback, useRef, useState, useEffect } from 'react';

import { ContextStoreDataOpts, ProvideConstateDataReturnType, ContextStoreDataUpdate, UpdateFunc } from './types';

export const useContextStore = <T>(
  initialValue: T,
  { notNeedRerender = false, handleBeforeUpdate, onAfterAUpdate }: ContextStoreDataOpts<T> = {},
): ProvideConstateDataReturnType<T> => {
  const ref = useRef<T>(initialValue);
  const queueRef = useRef<{ valOrFunc: Partial<T> | UpdateFunc<T>; force: boolean }[]>([]);
  const [, setRerenderKey] = useState(0);

  const refWrapper = useRef({ notNeedRerender, handleBeforeUpdate, onAfterAUpdate });
  refWrapper.current = { notNeedRerender, handleBeforeUpdate, onAfterAUpdate };

  const update: ContextStoreDataUpdate<T> = useCallback((valOrFunc, force = false) => {
    queueRef.current.push({ valOrFunc, force });
  }, []);

  const processNextQueue = useCallback(() => {
    const next = queueRef.current.shift();

    if (!next) {
      return;
    }

    const { valOrFunc, force } = next;

    // It need to force prevent unnecessary rerendering
    // update will create once
    const { notNeedRerender, handleBeforeUpdate, onAfterAUpdate } = refWrapper.current;
    // eslint-disable-next-line @typescript-eslint/ban-ts-comment
    // @ts-expect-error
    const availableKeys = Object.keys(ref.current);

    const values = typeof valOrFunc === 'function' ? valOrFunc(ref.current) : valOrFunc;

    let callRerender = false;
    Object.keys(values).forEach(key => {
      if (!availableKeys.includes(key)) {
        // TODO maybe need show error
        return;
      }

      if (!handleBeforeUpdate || force) {
        // eslint-disable-next-line @typescript-eslint/ban-ts-comment
        // @ts-expect-error
        ref.current[key] = values[key];
        // !notNeedRerender && setRerenderKey(x => x + 1);
        if (!notNeedRerender) {
          callRerender = true;
        }
        return;
      }
      // eslint-disable-next-line @typescript-eslint/ban-ts-comment
      // @ts-expect-error
      const updateResult = handleBeforeUpdate(values[key], ref.current[key]);
      if (!updateResult) {
        // eslint-disable-next-line @typescript-eslint/ban-ts-comment
        // @ts-expect-error
        ref.current[key] = values[key];
        // !notNeedRerender && setRerenderKey(x => x + 1);
        if (!notNeedRerender) {
          callRerender = true;
        }
        return;
      }

      if (updateResult?.prevent) {
        return;
      }

      if (Object.keys(updateResult).includes('value')) {
        // eslint-disable-next-line @typescript-eslint/ban-ts-comment
        // @ts-expect-error
        ref.current[key] = updateResult.value;
        // !notNeedRerender && setRerenderKey(x => x + 1);
        if (!notNeedRerender) {
          callRerender = true;
        }
        return;
      }
    });

    if (callRerender) {
      setRerenderKey(x => x + 1);
    }

    onAfterAUpdate?.(ref.current);
  }, []);

  useEffect(() => {
    let requestId: number;
    const process = () => {
      processNextQueue();
      requestId = requestAnimationFrame(process);
    };

    process();

    return () => {
      cancelAnimationFrame(requestId);
    };
  });

  return { update, ref: ref.current };
};
