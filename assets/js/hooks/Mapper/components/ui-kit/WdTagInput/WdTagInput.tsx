import clsx from 'clsx';
import { Tag } from 'primereact/tag';
import { useLayoutEffect, useRef, useState } from 'react';
import type { ReactNode } from 'react';

const TAG_GAP_PX = 6;

export interface WdTagInputProps<T> {
  className?: string;
  items: readonly T[];
  getItemKey: (item: T) => string | number;
  renderItem: (item: T) => ReactNode;
  onRemove: (item: T) => void;
  onOpen: () => void;
  placeholder?: string;
  addLabel?: string;
}

export const WdTagInput = <T,>({
  className,
  items,
  getItemKey,
  renderItem,
  onRemove,
  onOpen,
  placeholder = 'Select items',
  addLabel = 'Add item',
}: WdTagInputProps<T>) => {
  const viewportRef = useRef<HTMLDivElement>(null);
  const ellipsisRef = useRef<HTMLSpanElement>(null);
  const tagRefs = useRef(new Map<string | number, HTMLSpanElement>());
  const [visibleCount, setVisibleCount] = useState(items.length);

  useLayoutEffect(() => {
    const viewport = viewportRef.current;
    const ellipsis = ellipsisRef.current;
    if (!viewport || !ellipsis) {
      return;
    }

    const updateVisibleCount = () => {
      const widths = items.map(item => tagRefs.current.get(getItemKey(item))?.offsetWidth ?? 0);
      const styles = window.getComputedStyle(viewport);
      const horizontalPadding = parseFloat(styles.paddingLeft) + parseFloat(styles.paddingRight);
      const availableWidth = viewport.clientWidth - horizontalPadding;
      let occupiedWidth = 0;
      let count = 0;

      for (const width of widths) {
        const tagGap = count > 0 ? TAG_GAP_PX : 0;
        const hasMore = count + 1 < widths.length;
        const ellipsisWidth = hasMore ? ellipsis.offsetWidth + TAG_GAP_PX : 0;

        if (occupiedWidth + tagGap + width + ellipsisWidth > availableWidth) {
          break;
        }

        occupiedWidth += tagGap + width;
        count += 1;
      }

      setVisibleCount(count);
    };

    updateVisibleCount();
    const observer = new ResizeObserver(updateVisibleCount);
    observer.observe(viewport);
    tagRefs.current.forEach(element => observer.observe(element));
    return () => observer.disconnect();
  }, [getItemKey, items, renderItem]);

  const hiddenCount = items.length - visibleCount;

  return (
    <div
      className={clsx(
        'flex min-h-9 w-full min-w-0 max-w-full items-center overflow-hidden border border-stone-700 bg-stone-950/50',
        'focus-within:border-sky-600 hover:border-stone-600',
        className,
      )}
    >
      <div
        ref={viewportRef}
        className="relative flex min-w-0 flex-1 cursor-pointer items-center gap-1.5 overflow-hidden px-2 py-1"
        role="group"
        aria-label={addLabel}
        onClick={onOpen}
      >
        {items.length === 0 && <span className="text-xs text-stone-500">{placeholder}</span>}
        {items.map((item, index) => {
          const itemKey = getItemKey(item);
          const isVisible = index < visibleCount;

          return (
            <span
              key={itemKey}
              ref={element => {
                if (element) {
                  tagRefs.current.set(itemKey, element);
                  return;
                }

                tagRefs.current.delete(itemKey);
              }}
              className={clsx('shrink-0', {
                'pointer-events-none absolute invisible': !isVisible,
              })}
              aria-hidden={!isVisible}
            >
              <Tag
                className="rounded-none border border-stone-700 bg-stone-900 px-1.5 py-0.5 text-xs font-normal"
                value={
                  <span className="flex items-center gap-1">
                    {renderItem(item)}
                    <button
                      type="button"
                      tabIndex={isVisible ? 0 : -1}
                      className="pi pi-times text-[0.55rem] text-stone-500 hover:text-red-400"
                      aria-label="Remove item"
                      onClick={event => {
                        event.stopPropagation();
                        onRemove(item);
                      }}
                    />
                  </span>
                }
              />
            </span>
          );
        })}
        {hiddenCount > 0 && (
          <Tag
            className="shrink-0 rounded-none border border-stone-700 bg-stone-900 px-2 py-0.5 text-xs font-normal text-stone-300"
            value={`+${hiddenCount} ...`}
            title={`${hiddenCount} more`}
          />
        )}
      </div>

      <span ref={ellipsisRef} className="pointer-events-none absolute invisible">
        <Tag className="rounded-none border px-2 py-0.5 text-xs" value={`+${items.length} ...`} />
      </span>

      <button
        type="button"
        className="pi pi-plus mx-2 shrink-0 text-xs text-sky-400 hover:text-sky-300"
        aria-label={addLabel}
        title={addLabel}
        onClick={onOpen}
      />
    </div>
  );
};
