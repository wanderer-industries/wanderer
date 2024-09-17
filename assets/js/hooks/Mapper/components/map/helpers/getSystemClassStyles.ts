import { isKnownSpace } from '@/hooks/Mapper/components/map/helpers/isKnownSpace.ts';
import {
  SECURITY_FOREGROUND_CLASSES,
  SYSTEM_CLASS_STYLES,
  WORMHOLE_CLASS_STYLES,
} from '@/hooks/Mapper/components/map/constants.ts';
import { isWormholeSpace } from '@/hooks/Mapper/components/map/helpers/isWormholeSpace.ts';
import { SolarSystemStaticInfo } from '@/hooks/Mapper/types';

type SystemClassStylesProps = Pick<SolarSystemStaticInfo, 'systemClass' | 'security'>;

export const getSystemClassStyles = ({ systemClass, security }: SystemClassStylesProps) => {
  if (isKnownSpace(systemClass)) {
    return SECURITY_FOREGROUND_CLASSES[security];
  }

  if (isWormholeSpace(systemClass)) {
    return WORMHOLE_CLASS_STYLES[systemClass];
  }

  return SYSTEM_CLASS_STYLES[systemClass];
};

