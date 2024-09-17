/* Phoenix Socket and LiveView configuration. */

import { Socket } from 'phoenix';
import { LiveSocket } from 'phoenix_live_view';
import live_select from 'live_select';

import topbar from 'topbar';

import customHooks from '../../js/hooks';

const csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute('content');

const basePath = document.querySelector('html').dataset.basePath || '';

const hooks = {
  ...customHooks,
  ...live_select,
};

const liveSocket = new LiveSocket(`${basePath}/live`, Socket, {
  params: { _csrf_token: csrfToken },
  hooks,
});

topbar.config({
  barThickness: 2,
  barColors: {
    0: 'rgba(0,  0, 0, .7)',
    '1.0': 'rgba(34, 197, 94, .7)',
  },
  shadowColor: 'rgba(0, 0, 0, .3)',
});

const timeouts = new Map();

const execJS = (selector, attr) => {
  document.querySelectorAll(selector).forEach(el => liveSocket.execJS(el, el.getAttribute(attr)));
};

// Show progress bar on live navigation and form submits if the results do not appear within 200ms.
window.addEventListener('phx:page-loading-start', _info => topbar.show(500));
window.addEventListener('phx:page-loading-stop', _info => topbar.hide());
// loading transitions
window.addEventListener('phx:page-loading-start', info => {
  if (info.detail.kind == 'redirect') {
    const main = document.querySelector('.main');
    main.classList.add('phx-page-loading');
  }
});

window.addEventListener('phx:page-loading-stop', info => {
  const main = document.querySelector('.main');
  if (main) {
    main.classList.remove('phx-page-loading');
  }
});

window.addEventListener('phx:js-exec', ({ detail }) => {
  document.querySelectorAll(detail.to).forEach(el => {
    if (detail.timeout) {
      if (timeouts.has(detail.to)) {
        clearTimeout(timeouts.get(detail.to));
      }
      timeouts.set(
        detail.to,
        setTimeout(() => liveSocket.execJS(el, el.getAttribute(detail.attr)), detail.timeout),
      );
    } else {
      if (timeouts.has(detail.to)) {
        clearTimeout(timeouts.get(detail.to));
      }
      liveSocket.execJS(el, el.getAttribute(detail.attr));
    }
  });
});

window.addEventListener('phx:toggle-on', e => {
  let el = document.getElementById(e.detail.id);
  if (el) {
    el.checked = true;
  }
});

window.addEventListener('phx:live_reload:attached', ({ detail: reloader }) => {
  // Enable server log streaming to client.
  // Disable with reloader.disableServerLogs()
  // reloader.enableServerLogs();
  window.liveReloader = reloader;
});

window.addEventListener('phx:fade-out-flash', e => {
  const targetAttr = 'data-handle-fadeout-flash';
  document.querySelectorAll(`[${targetAttr}]`).forEach(el => {
    const key = el.getAttribute('phx-value-key');
    if (key == e.detail.type) {
      liveSocket.execJS(el, el.getAttribute(targetAttr));
    }
  });
});

// connect if there are any LiveViews on the page
liveSocket.getSocket().onOpen(() => execJS('#connection-status', 'js-hide'));
liveSocket.getSocket().onClose(() => execJS('#connection-status', 'js-show'));
liveSocket.getSocket().onError(() => execJS('#connection-status', 'js-show'));

liveSocket.connect();

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket;
