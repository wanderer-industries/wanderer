const countdown = (secondsCount: number) => {
  let minutes, seconds;

  const dateEnd = new Date().getTime() + secondsCount * 1000;

  const timer = setInterval(calculate, 1000);

  function calculate() {
    const dateStartDefault = new Date();
    const dateStart = new Date(
      dateStartDefault.getUTCFullYear(),
      dateStartDefault.getUTCMonth(),
      dateStartDefault.getUTCDate(),
      dateStartDefault.getUTCHours(),
      dateStartDefault.getUTCMinutes(),
      dateStartDefault.getUTCSeconds(),
    );
    let timeRemaining = parseInt((dateEnd - dateStart.getTime()) / 1000);

    if (timeRemaining >= 0) {
      timeRemaining = timeRemaining % 86400;
      timeRemaining = timeRemaining % 3600;
      minutes = parseInt(timeRemaining / 60);
      timeRemaining = timeRemaining % 60;
      seconds = parseInt(timeRemaining);

      document.getElementById('version-update-seconds').innerHTML = minutes * 60 + seconds;
    } else {
      return;
    }
  }
};

const LAST_VERSION_KEY = 'wandererLastVersion';

const updateVerion = (newVersion: string) => {
  localStorage.setItem(LAST_VERSION_KEY, newVersion);

  window.location.reload();
};

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

      updateVerion(hook.el.dataset.version);
    };

    refreshZone.addEventListener('click', handleUpdate);
    refreshZone.addEventListener('mouseover', handleUpdate);

    this.updated();
  },

  reconnected() {
    this.updated();
  },

  updated() {
    const hook = this;
    const activeVersion = this.getItem(LAST_VERSION_KEY);
    const lastVersion = hook.el.dataset.version;
    if (activeVersion === lastVersion) {
      return;
    }
    const enabled = hook.el.dataset.enabled;
    if (enabled === 'true') {
      hook.el.classList.remove('hidden');
      const autoRefreshTimeout = Math.floor(Math.random() * (150 - 75 + 1)) + 75;
      countdown(autoRefreshTimeout);
      setTimeout(() => {
        updateVerion(hook.el.dataset.version);
      }, autoRefreshTimeout * 1000);
    } else {
      updateVerion(hook.el.dataset.version);
    }
  },

  getItem(key: string) {
    return localStorage.getItem(key);
  },

  setItem(key: string, value: string) {
    return localStorage.setItem(key, value);
  },
};
