export default {
  content: '',

  mounted() {
    const hook = this;
    const button = this.el;

    button.addEventListener('click', function () {
      // Create a Blob from the JSON string
      const blob = new Blob([hook.el.dataset.content || '{}'], { type: 'application/json' });

      // Create a link element
      const link = document.createElement('a');

      // Set the download attribute with a filename
      link.download = `${hook.el.dataset.name}.json`;

      // Create a URL for the Blob and set it as the href attribute
      link.href = URL.createObjectURL(blob);

      // Append the link to the body (it won't be visible)
      document.body.appendChild(link);

      // Programmatically click the link to trigger the download
      link.click();

      // Remove the link from the document
      document.body.removeChild(link);
    });
  },
};
