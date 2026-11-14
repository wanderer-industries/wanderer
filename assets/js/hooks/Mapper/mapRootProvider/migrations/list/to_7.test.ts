import { SIGNATURES_GLOWINGROWS_TIMING } from '@/hooks/Mapper/constants/signatures.ts';
import { to_7 } from './to_7.ts';

describe('to_7', () => {
  it('adds the default paste flash timing to signature widget settings', () => {
    const previousSettings = {
      signaturesWidget: {
        color_by_type: false,
      },
    };

    expect(to_7.up(previousSettings).signaturesWidget).toEqual({
      color_by_type: false,
      glowingrows_timing: SIGNATURES_GLOWINGROWS_TIMING.GLOWDEFAULT,
    });
  });

  it('preserves an existing paste flash timing', () => {
    const previousSettings = {
      signaturesWidget: {
        glowingrows_timing: SIGNATURES_GLOWINGROWS_TIMING.GLOWEXTENDED,
      },
    };

    expect(to_7.up(previousSettings).signaturesWidget.glowingrows_timing).toBe(
      SIGNATURES_GLOWINGROWS_TIMING.GLOWEXTENDED,
    );
  });
});
