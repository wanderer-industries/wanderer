const LAST_VERSION_KEY = 'wandererLastVersion';

export default {
  mounted() {
    const hook = this;

    const button = hook.el.querySelector('.update-button');

    button.addEventListener('click', function () {
      const lastVersion = hook.el.dataset.version;
      localStorage.setItem(LAST_VERSION_KEY, lastVersion);
      window.location.reload();
    });

    this.updated();
  },

  reconnected() {
    this.updated();
  },

  updated() {
    const activeVersion = this.getItem(LAST_VERSION_KEY);
    const lastVersion = this.el.dataset.version;
    if (activeVersion === lastVersion) {
      return;
    }
    this.el.classList.remove('hidden');
  },

  getItem(key: string) {
    return localStorage.getItem(key);
  },

  setItem(key: string, value: string) {
    return localStorage.setItem(key, value);
  },
};
