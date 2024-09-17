export default {
  mounted() {
    const hook = this;
    const url = hook.el.dataset.url;
    const button = hook.el;

    button.addEventListener('click', function () {
      // Get the URL from the data attribute

      button.classList.remove('copied');

      // Copy the URL to the clipboard
      navigator.clipboard
        .writeText(url)
        .then(() => {
          button.classList.add('copied');
        })
        .catch(err => {
          console.error('Failed to copy URL:', err);
        });
    });
  },
};
