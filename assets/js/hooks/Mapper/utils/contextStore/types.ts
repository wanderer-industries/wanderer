export type AnyProperty<T> = T[keyof T];

export type PCDHandleBeforeUpdate<T> = (
  newVal: AnyProperty<T>,
  prev: AnyProperty<T>,
) => {
  value: AnyProperty<T>;
  prevent?: boolean;
} | void;

export type UpdateFunc<T> = (props: T) => Partial<T>;
export type ContextStoreDataUpdate<T> = (values: Partial<T> | UpdateFunc<T>, force?: boolean) => void;

export type ContextStoreDataOpts<T> = {
  notNeedRerender?: boolean;
  handleBeforeUpdate?: PCDHandleBeforeUpdate<T>;
  onAfterAUpdate?: (values: Partial<T>) => void;
};

export type ProvideConstateDataReturnType<T> = {
  update: ContextStoreDataUpdate<T>;
  ref: T;
};
