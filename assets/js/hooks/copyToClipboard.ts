export default {
  mounted() {
    const button = this.el;

    button.addEventListener('click', function () {

      button.classList.remove('copied');

      // Copy the URL to the clipboard
      navigator.clipboard
        .writeText(button.dataset.url)
        .then(() => {
          button.classList.add('copied');
        })
        .catch(err => {
          console.error('Failed to copy URL:', err);
        });
    });
  },
};
