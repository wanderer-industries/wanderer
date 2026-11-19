import { useCallback, useEffect, useRef } from 'react';

export interface UseAudioPlayerOptions {
  volume?: number;
}

const DEFAULT_AUDIO_PLAYER_OPTIONS: UseAudioPlayerOptions = {};

export const useAudioPlayer = (source: string, options: UseAudioPlayerOptions = DEFAULT_AUDIO_PLAYER_OPTIONS) => {
  const { volume = 1 } = options;
  const audioRef = useRef<HTMLAudioElement | null>(null);

  useEffect(() => {
    const audio = new Audio(source);
    audio.preload = 'auto';
    audio.volume = volume;
    audioRef.current = audio;

    let isUnlocking = false;

    const removeUnlockListeners = () => {
      window.removeEventListener('pointerdown', unlockAudio);
      window.removeEventListener('keydown', unlockAudio);
    };

    const unlockAudio = () => {
      if (isUnlocking) {
        return;
      }

      isUnlocking = true;
      const currentVolume = audio.volume;
      audio.volume = 0;

      audio
        .play()
        .then(() => {
          audio.pause();
          audio.currentTime = 0;
          audio.volume = currentVolume;
          removeUnlockListeners();
        })
        .catch(() => {
          audio.volume = currentVolume;
          isUnlocking = false;
        });
    };

    window.addEventListener('pointerdown', unlockAudio);
    window.addEventListener('keydown', unlockAudio);

    return () => {
      removeUnlockListeners();
      audio.pause();
      audioRef.current = null;
    };
  }, [source, volume]);

  return useCallback(async () => {
    const audio = audioRef.current;
    if (!audio) {
      return;
    }

    audio.currentTime = 0;
    await audio.play();
  }, []);
};
