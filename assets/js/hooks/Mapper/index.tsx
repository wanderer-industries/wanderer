import { createRoot } from 'react-dom/client';
import Mapper from './MapRoot';

export default {
  _rootEl: null,
  _errorCount: 0,

  mounted() {
    // create react root element
    const rootEl = document.getElementById(this.el.id);
    this._version = this.el.dataset.version;
    this._rootEl = createRoot(rootEl!);

    const handleError = (error: Error, componentStack: string) => {
      this.pushEvent('log_map_error', { error: error.message, componentStack });
    };

    this.render({
      handleEvent: this.handleEventWrapper.bind(this),
      pushEvent: this.pushEvent.bind(this),
      pushEventAsync: this.pushEventAsync.bind(this),
      onError: handleError,
    });

    this.pushEvent('ui_loaded');
  },

  handleEventWrapper(event: string, handler: (payload: any) => void) {
    this.handleEvent(event, (body: any) => {
      handler(body);
    });
  },

  reconnected() {
    this.pushEvent('reconnected');
  },

  async pushEventAsync(event: string, payload: any) {
    return new Promise((accept, reject) => {
      this.pushEvent(event, payload, reply => {
        accept(reply);
      });
    });
  },

  render(hooks) {
    this._rootEl.render(<Mapper hooks={hooks} />);
  },
};
