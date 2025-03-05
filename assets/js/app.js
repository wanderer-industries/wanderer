// Add copy to clipboard functionality
window.addEventListener('phx:init-copy-to-clipboard', () => {
  window.addEventListener('phx:copy-to-clipboard', e => {
    const text = e.detail.text;
    if (navigator.clipboard) {
      navigator.clipboard.writeText(text)
        .then(() => {
          console.log('Text copied to clipboard');
        })
        .catch(err => {
          console.error('Failed to copy text: ', err);
        });
    } else {
      // Fallback for browsers that don't support clipboard API
      const textArea = document.createElement('textarea');
      textArea.value = text;
      textArea.style.position = 'fixed';
      document.body.appendChild(textArea);
      textArea.focus();
      textArea.select();
      try {
        document.execCommand('copy');
        console.log('Text copied to clipboard (fallback)');
      } catch (err) {
        console.error('Failed to copy text (fallback): ', err);
      }
      document.body.removeChild(textArea);
    }
  });
}); 