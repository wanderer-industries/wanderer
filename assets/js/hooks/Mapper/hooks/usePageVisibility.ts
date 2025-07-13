import { useState, useEffect } from 'react';

function usePageVisibility() {
  const getIsVisible = () => !document.hidden;
  const [isVisible, setIsVisible] = useState(getIsVisible());

  useEffect(() => {
    const handleVisibilityChange = () => {
      setIsVisible(getIsVisible());
    };

    document.addEventListener('visibilitychange', handleVisibilityChange);

    return () => {
      document.removeEventListener('visibilitychange', handleVisibilityChange);
    };
  }, []);

  return isVisible;
}

export default usePageVisibility;
