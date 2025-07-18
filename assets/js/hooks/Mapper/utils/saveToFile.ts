export function saveTextFile(filename: string, content: string) {
  const blob = new Blob([content], { type: 'text/plain;charset=utf-8' });
  const url = URL.createObjectURL(blob);

  const a = document.createElement('a');
  a.href = url;
  a.download = filename;

  document.body.appendChild(a);
  a.click();
  document.body.removeChild(a);
  URL.revokeObjectURL(url);
}

export async function saveTextFileInteractive(filename: string, content: string) {
  if (!('showSaveFilePicker' in window)) {
    throw new Error('File System Access API is not supported in this browser.');
  }

  const handle = await (window as any).showSaveFilePicker({
    suggestedName: filename,
    types: [
      {
        description: 'Text Files',
        accept: { 'text/plain': ['.txt', '.json'] },
      },
    ],
  });

  const writable = await handle.createWritable();
  await writable.write(content);
  await writable.close();
}
