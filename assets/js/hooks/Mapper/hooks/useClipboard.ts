import { useState, useEffect, useCallback } from 'react';

export const useClipboard = () => {
  const [clipboardContent, setClipboardContent] = useState<{ text: string } | null>(null);
  const [error, setError] = useState<string | null>(null);

  const getClipboardContent = useCallback(async () => {
    try {
      const text = await navigator.clipboard.readText();
      setClipboardContent({ text });
      setError(null);
    } catch (err) {
      setError('Failed to read clipboard content.');
    }
  }, []);

  useEffect(() => {
    const handlePaste = (event: ClipboardEvent) => {
      const text = event.clipboardData?.getData('text');
      if (text) {
        setClipboardContent({ text });
        setError(null);
      }
    };

    window.addEventListener('paste', handlePaste);

    return () => {
      window.removeEventListener('paste', handlePaste);
    };
  }, []);

  return { clipboardContent, error, getClipboardContent, setClipboardContent };
};
