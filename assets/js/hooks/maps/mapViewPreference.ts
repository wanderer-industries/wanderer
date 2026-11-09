const STORAGE_KEY = 'wanderer:maps:view-mode';
const VIEW_MODE_SELECTOR = '[data-map-view-mode]';
const ALLOWED_VIEW_MODES = new Set(['compact', 'cards']);

const readStoredViewMode = () => {
  try {
    const mode = localStorage.getItem(STORAGE_KEY);
    if (!mode || !ALLOWED_VIEW_MODES.has(mode)) return null;
    return mode;
  } catch {
    return null;
  }
};

const storeViewMode = (mode: string) => {
  try {
    localStorage.setItem(STORAGE_KEY, mode);
  } catch {
    // Storage can be unavailable in restricted browser contexts.
  }
};

export default {
  mounted() {
    this.handleViewModeClick = (event: Event) => {
      if (!(event.target instanceof Element)) return;

      const button = event.target.closest<HTMLElement>(VIEW_MODE_SELECTOR);
      if (!button || !this.el.contains(button)) return;

      const mode = button.dataset.mapViewMode;
      if (!mode || !ALLOWED_VIEW_MODES.has(mode)) return;

      storeViewMode(mode);
    };

    this.el.addEventListener('click', this.handleViewModeClick);

    const storedMode = readStoredViewMode();
    if (!storedMode || storedMode === this.el.dataset.currentViewMode) return;

    this.pushEvent('set-map-view', { mode: storedMode });
  },

  destroyed() {
    this.el.removeEventListener('click', this.handleViewModeClick);
  },
};
