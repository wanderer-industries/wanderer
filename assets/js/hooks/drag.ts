import { Droppable } from '@shopify/draggable';

export default {
  mounted() {
    let lastDropzone = null;
    const hook = this;
    const containers = document.querySelectorAll('.dropzone');
    const selector = '#' + this.el.id;

    const droppable = new Droppable(containers, {
      delay: 100,
      draggable: '.draggable',
      dropzone: '.dropzone',
      mirror: {
        constrainDimensions: true,
      },
    });

    let droppableOrigin;

    // --- Draggable events --- //
    droppable.on('drag:start', evt => {
      lastDropzone = null;
      droppableOrigin = evt.originalSource;
    });

    droppable.on('droppable:dropped', evt => {
      if (droppableOrigin.parentNode.dataset.dropzone !== evt.dropzone.dataset.dropzone) {
        lastDropzone = evt.dropzone.dataset.dropzone;
        evt.cancel();
      }
    });

    droppable.on('droppable:stop', evt => {
      if (!lastDropzone) {
        return;
      }
      hook.pushEventTo(selector, 'dropped', { draggedId: droppableOrigin.id, dropzoneId: lastDropzone });
    });
  },
};
