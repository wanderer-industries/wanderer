export default {
  mounted() {
    this.updated();
  },
  updated() {
    const dt = new Date(Number(this.el.textContent));
    const options = { hour12: false, timeZone: 'UTC' };
    this.el.textContent = `${dt.toLocaleString('en-US', options)}`;
    this.el.classList.remove('invisible');
  },
};
