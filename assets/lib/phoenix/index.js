// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import 'phoenix_html';

import './live_reload.css';

document.addEventListener('DOMContentLoaded', function () {
  // Select all buttons with the 'share-link' class
  const buttons = document.querySelectorAll('button.copy-link');

  buttons.forEach(button => {
    button.addEventListener('click', function () {
      // Get the URL from the data attribute
      const url = button.dataset.url;

      button.classList.remove('copied');

      // Copy the URL to the clipboard
      navigator.clipboard
        .writeText(url)
        .then(() => {
          // Add the 'copied' class to the button
          button.classList.add('copied');
        })
        .catch(err => {
          console.error('Failed to copy URL:', err);
        });
    });
  });

  const navbar = document.querySelector('navbar.navbar');

  const scrollState = {
    top: true,
    topThreshold: 10,
    onScroll: function () {
      if (this.top && window.scrollY > this.topThreshold) {
        this.top = false;
        this.updateUI();
      } else if (!this.top && window.scrollY <= this.topThreshold) {
        this.top = true;
        this.updateUI();
      }
    },
    updateUI: function () {
      navbar.classList.toggle('bg-opacity-30');
      navbar.classList.toggle('backdrop-filter');
      navbar.classList.toggle('backdrop-blur-lg');
    },
  };
  window.addEventListener('scroll', () => scrollState.onScroll());
});
