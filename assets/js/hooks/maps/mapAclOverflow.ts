const ACL_CHIP_SELECTOR = '[data-map-acl-chip]';
const ACL_OVERFLOW_SELECTOR = '[data-map-acl-overflow]';

const updateAclOverflow = (container: HTMLElement) => {
  const chips = Array.from(container.querySelectorAll<HTMLElement>(ACL_CHIP_SELECTOR));
  const overflow = container.querySelector<HTMLElement>(ACL_OVERFLOW_SELECTOR);

  if (!overflow) return;

  chips.forEach(chip => {
    chip.hidden = true;
  });

  let visibleCount = 0;
  overflow.hidden = chips.length === 0;

  for (const chip of chips) {
    chip.hidden = false;
    visibleCount += 1;

    const remainingCount = chips.length - visibleCount;
    overflow.hidden = remainingCount === 0;
    overflow.textContent = `+${remainingCount}`;

    if (container.scrollHeight <= container.clientHeight) continue;

    chip.hidden = true;
    visibleCount -= 1;
    break;
  }

  chips.slice(visibleCount).forEach(chip => {
    chip.hidden = true;
  });

  let hiddenCount = chips.length - visibleCount;
  overflow.hidden = hiddenCount === 0;
  overflow.textContent = `+${hiddenCount}`;

  while (hiddenCount > 0 && container.scrollHeight > container.clientHeight && visibleCount > 0) {
    visibleCount -= 1;
    hiddenCount += 1;
    chips[visibleCount].hidden = true;
    overflow.textContent = `+${hiddenCount}`;
  }

  const hiddenNames = chips
    .slice(visibleCount)
    .map(chip => chip.textContent?.trim())
    .filter(Boolean)
    .join(', ');

  overflow.title = hiddenNames;
  overflow.setAttribute('aria-label', `${hiddenCount} more access lists: ${hiddenNames}`);
};

export default {
  mounted() {
    this.updateAclOverflow = () => updateAclOverflow(this.el);
    this.resizeObserver = new ResizeObserver(this.updateAclOverflow);
    this.resizeObserver.observe(this.el);
    this.updateAclOverflow();
  },

  updated() {
    this.updateAclOverflow();
  },

  destroyed() {
    this.resizeObserver.disconnect();
  },
};
