import { useCallback, useState } from 'react';

import { ContextStoreDataOpts, ProvideConstateDataReturnType, ContextStoreDataUpdate } from './types';

export const useContextStore = <T extends object>(
  initialValue: T,
  { notNeedRerender = false, handleBeforeUpdate, onAfterAUpdate }: ContextStoreDataOpts<T> = {},
): ProvideConstateDataReturnType<T> => {
  const [store, setStore] = useState<T>(initialValue);

  const update: ContextStoreDataUpdate<T> = useCallback(
    (valOrFunc, force = false) => {
      setStore(prevStore => {
        const values = typeof valOrFunc === 'function' ? valOrFunc(prevStore) : valOrFunc;

        const next = { ...prevStore };
        let didChange = false;

        Object.keys(values).forEach(k => {
          const key = k as keyof T;

          if (!(key in prevStore)) {
            return;
          }

          if (handleBeforeUpdate && !force) {
            const newVal = values[key];
            const oldVal = next[key];
            const updateResult = handleBeforeUpdate(newVal, oldVal);

            if (!updateResult) {
              (next[key] as T[keyof T]) = newVal as T[keyof T];
              didChange = didChange || newVal !== oldVal;
              return;
            }

            if (updateResult.prevent) {
              return;
            }

            if ('value' in updateResult) {
              const finalVal = updateResult.value as T[keyof T];
              (next[key] as T[keyof T]) = finalVal;
              didChange = didChange || finalVal !== oldVal;
            } else {
              (next[key] as T[keyof T]) = newVal as T[keyof T];
              didChange = didChange || newVal !== oldVal;
            }
          } else {
            const newVal = values[key] as T[keyof T];
            const oldVal = next[key];
            (next[key] as T[keyof T]) = newVal;
            didChange = didChange || newVal !== oldVal;
          }
        });

        if (!didChange && notNeedRerender) {
          return prevStore;
        }

        onAfterAUpdate?.(next);

        return next;
      });
    },
    [handleBeforeUpdate, onAfterAUpdate, notNeedRerender],
  );

  return { update, ref: store };
};
