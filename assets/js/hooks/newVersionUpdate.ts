const LAST_VERSION_KEY = 'wandererLastVersion';

export default {
  mounted() {
    const hook = this;

    const refreshZone = hook.el.querySelector('#refresh-area');

    const handleUpdate = function (e: Event) {
      const hexBricks = hook.el.querySelectorAll('.hex-brick');

      // Add a new class to each element
      hexBricks.forEach(el => {
        el.classList.add('hex-brick--active');
      });

      setTimeout(() => {
        const lastVersion = hook.el.dataset.version;
        localStorage.setItem(LAST_VERSION_KEY, lastVersion);

        window.location.reload();
      }, 2000);
    };

    refreshZone.addEventListener('click', handleUpdate);
    refreshZone.addEventListener('mouseover', handleUpdate);

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
