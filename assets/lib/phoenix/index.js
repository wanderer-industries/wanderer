// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import 'phoenix_html';

import './live_reload.css';

const animateBg = function (bgCanvas) {
  const { TweenMax } = window;
  /**
   * Utility function for returning a random integer in a given range
   * @param {Int} max
   * @param {Int} min
   */
  const randomInRange = (max, min) => Math.floor(Math.random() * (max - min + 1)) + min;
  const BASE_SIZE = 1;
  const VELOCITY_INC = 1.01;
  const VELOCITY_INIT_INC = 0.525;
  const JUMP_VELOCITY_INC = 0.55;
  const JUMP_SIZE_INC = 1.15;
  const SIZE_INC = 1.01;
  const RAD = Math.PI / 180;
  const WARP_COLORS = [
    [197, 239, 247],
    [25, 181, 254],
    [77, 5, 232],
    [165, 55, 253],
    [255, 255, 255],
  ];
  /**
   * Class for storing the particle metadata
   * position, size, length, speed etc.
   */
  class Star {
    STATE = {
      alpha: Math.random(),
      angle: randomInRange(0, 360) * RAD,
    };
    reset = () => {
      const angle = randomInRange(0, 360) * (Math.PI / 180);
      const vX = Math.cos(angle);
      const vY = Math.sin(angle);
      const travelled =
        Math.random() > 0.5
          ? Math.random() * Math.max(window.innerWidth, window.innerHeight) + Math.random() * (window.innerWidth * 0.24)
          : Math.random() * (window.innerWidth * 0.25);
      this.STATE = {
        ...this.STATE,
        iX: undefined,
        iY: undefined,
        active: travelled ? true : false,
        x: Math.floor(vX * travelled) + window.innerWidth / 2,
        vX,
        y: Math.floor(vY * travelled) + window.innerHeight / 2,
        vY,
        size: BASE_SIZE,
      };
    };
    constructor() {
      this.reset();
    }
  }

  const generateStarPool = size => new Array(size).fill().map(() => new Star());

  // Class for the actual app
  // Not too much happens in here
  // Initiate the drawing process and listen for user interactions 👍
  class JumpToHyperspace {
    STATE = {
      stars: generateStarPool(300),
      bgAlpha: 0,
      sizeInc: SIZE_INC,
      velocity: VELOCITY_INC,
    };
    canvas = null;
    context = null;
    constructor(canvas) {
      this.canvas = canvas;
      this.context = canvas.getContext('2d');
      this.bind();
      this.setup();
      this.render();
    }
    render = () => {
      const {
        STATE: { bgAlpha, velocity, sizeInc, initiating, jumping, stars },
        context,
        render,
      } = this;
      // Clear the canvas
      context.clearRect(0, 0, window.innerWidth, window.innerHeight);
      if (bgAlpha > 0) {
        context.fillStyle = `rgba(31, 58, 157, ${bgAlpha})`;
        context.fillRect(0, 0, window.innerWidth, window.innerHeight);
      }
      // 1. Shall we add a new star
      const nonActive = stars.filter(s => !s.STATE.active);
      if (!initiating && nonActive.length > 0) {
        // Introduce a star
        nonActive[0].STATE.active = true;
      }
      // 2. Update the stars and draw them.
      for (const star of stars.filter(s => s.STATE.active)) {
        const { active, x, y, iX, iY, iVX, iVY, size, vX, vY } = star.STATE;
        // Check if the star needs deactivating
        if (
          ((iX || x) < 0 || (iX || x) > window.innerWidth || (iY || y) < 0 || (iY || y) > window.innerHeight) &&
          active &&
          !initiating
        ) {
          star.reset(true);
        } else if (active) {
          const newIX = initiating ? iX : iX + iVX;
          const newIY = initiating ? iY : iY + iVY;
          const newX = x + vX;
          const newY = y + vY;
          // Just need to work out if it overtakes the original line that's all
          const caught =
            (vX < 0 && newIX < x) || (vX > 0 && newIX > x) || (vY < 0 && newIY < y) || (vY > 0 && newIY > y);
          star.STATE = {
            ...star.STATE,
            iX: caught ? undefined : newIX,
            iY: caught ? undefined : newIY,
            iVX: caught ? undefined : iVX * VELOCITY_INIT_INC,
            iVY: caught ? undefined : iVY * VELOCITY_INIT_INC,
            x: newX,
            vX: star.STATE.vX * velocity,
            y: newY,
            vY: star.STATE.vY * velocity,
            size: initiating ? size : size * (iX || iY ? SIZE_INC : sizeInc),
          };
          let color = `rgba(255, 255, 255, ${star.STATE.alpha})`;
          if (jumping) {
            const [r, g, b] = WARP_COLORS[randomInRange(0, WARP_COLORS.length)];
            color = `rgba(${r}, ${g}, ${b}, ${star.STATE.alpha})`;
          }
          context.strokeStyle = color;
          context.lineWidth = size;
          context.beginPath();
          context.moveTo(star.STATE.iX || x, star.STATE.iY || y);
          context.lineTo(star.STATE.x, star.STATE.y);
          context.stroke();
        }
      }
      requestAnimationFrame(render);
    };
    initiate = () => {
      if (this.STATE.jumping || this.STATE.initiating) return;
      this.STATE = {
        ...this.STATE,
        initiating: true,
        initiateTimestamp: new Date().getTime(),
      };
      TweenMax.to(this.STATE, 0.25, { velocity: VELOCITY_INIT_INC, bgAlpha: 0.3 });
      // When we initiate, stop the XY origin from moving so that we draw
      // longer lines until the jump
      for (const star of this.STATE.stars.filter(s => s.STATE.active)) {
        star.STATE = {
          ...star.STATE,
          iX: star.STATE.x,
          iY: star.STATE.y,
          iVX: star.STATE.vX,
          iVY: star.STATE.vY,
        };
      }
    };
    jump = () => {
      this.STATE = {
        ...this.STATE,
        bgAlpha: 0,
        jumping: true,
      };
      TweenMax.to(this.STATE, 0.25, { velocity: JUMP_VELOCITY_INC, bgAlpha: 0.75, sizeInc: JUMP_SIZE_INC });
      setTimeout(() => {
        this.STATE = {
          ...this.STATE,
          jumping: false,
        };
        TweenMax.to(this.STATE, 0.25, { bgAlpha: 0, velocity: VELOCITY_INC, sizeInc: SIZE_INC });
      }, 5000);
    };
    enter = () => {
      if (this.STATE.jumping) return;
      const { initiateTimestamp } = this.STATE;
      this.STATE = {
        ...this.STATE,
        initiating: false,
        initiateTimestamp: undefined,
      };
      if (new Date().getTime() - initiateTimestamp > 600) {
        this.jump();
      } else {
        TweenMax.to(this.STATE, 0.25, { velocity: VELOCITY_INC, bgAlpha: 0 });
      }
    };
    bind = () => {
      this.canvas.addEventListener('mousedown', this.initiate);
      this.canvas.addEventListener('touchstart', this.initiate);
      this.canvas.addEventListener('mouseup', this.enter);
      this.canvas.addEventListener('touchend', this.enter);
    };
    setup = () => {
      this.context.lineCap = 'round';
      this.canvas.height = window.innerHeight;
      this.canvas.width = window.innerWidth;
    };
    reset = () => {
      this.STATE = {
        ...this.STATE,
        stars: generateStarPool(300),
      };
      this.setup();
    };
  }
  window.myJump = new JumpToHyperspace(bgCanvas);
};

document.addEventListener('DOMContentLoaded', function () {
  // animage background
  const canvas = document.getElementById('bg-canvas');
  if (canvas) {
    animateBg(canvas);
  }

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
