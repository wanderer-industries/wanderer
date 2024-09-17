export default {
  mounted() {
    const hook = this;
    this.el.addEventListener('click', e => {
      e.preventDefault();
      e.stopPropagation();
      if (hook.el.dataset.confirm) {
        if (!confirm(hook.el.dataset.confirm)) {
          return;
        }
      }
      this.pushEvent(hook.el.dataset.event, { data: hook.el.dataset.data });
    });
  },
};
