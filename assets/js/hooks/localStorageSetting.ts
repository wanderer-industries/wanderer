export default {
  key(): string {
    return this.el.dataset.key;
  },

  getItem(key: string) {
    return localStorage.getItem(key);
  },

  setItem(key: string, value: string) {
    return localStorage.setItem(key, value);
  },

  mounted() {
    const key = this.key();
    this.pushEvent(`ls_restore_${key}`, { value: this.getItem(key) });
    this.handleEvent(`ls_update_${key}`, ({ value }) => this.setItem(key, value));
  },
};
