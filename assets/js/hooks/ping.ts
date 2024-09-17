export default {
  _nowMs: Date.now(),

  mounted() {
    const hook = this;
    this.handleEvent('pong', () => {
      const rtt = Date.now() - this._nowMs;
      hook.el.dataset.tip = `ping: ${rtt}ms`;

      setTimeout(() => {
        hook.ping(rtt);
      }, 1000 * 60);
    });
    this.ping(null);
  },
  reconnected() {
    this.ping(null);
  },
  disconnected() {
    // this.el.dataset.tip = `ping: No connection`;
    // this.el.classList.add('text-red-500');
  },
  ping(rtt) {
    this._nowMs = Date.now();
    this.pushEvent('ping', { rtt: rtt });
  },
};
