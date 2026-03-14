import { WORMHOLE_CLASS_STYLES, WORMHOLES_ADDITIONAL_INFO } from '@/hooks/Mapper/components/map/constants';
import { K162_TYPES_MAP } from '@/hooks/Mapper/constants';
import { parseSignatureCustomInfo } from '@/hooks/Mapper/helpers/parseSignatureCustomInfo';
import { WormholeDataRaw } from '@/hooks/Mapper/types/wormholes';
import { SystemSignature } from '@/hooks/Mapper/types/signatures';

// Maps WORMHOLE_CLASS_STYLES CSS class names → CSS variable references for inline SVG fill.
// The CSS classes set `color: var(--eve-wh-type-color-*)`, but SVG `fill` needs an explicit value.
const CLASS_NAME_TO_CSS_VAR: Record<string, string> = {
  'eve-wh-type-color-c1': 'var(--eve-wh-type-color-c1)',
  'eve-wh-type-color-c2': 'var(--eve-wh-type-color-c2)',
  'eve-wh-type-color-c3': 'var(--eve-wh-type-color-c3)',
  'eve-wh-type-color-c4': 'var(--eve-wh-type-color-c4)',
  'eve-wh-type-color-c5': 'var(--eve-wh-type-color-c5)',
  'eve-wh-type-color-c6': 'var(--eve-wh-type-color-c6)',
  'eve-wh-type-color-high': 'var(--eve-wh-type-color-high)',
  'eve-wh-type-color-low': 'var(--eve-wh-type-color-low)',
  'eve-wh-type-color-null': 'var(--eve-wh-type-color-null)',
  'eve-wh-type-color-thera': 'var(--eve-wh-type-color-thera)',
  'eve-wh-type-color-c13': 'var(--eve-wh-type-color-c13)',
  'eve-wh-type-color-drifter': 'var(--eve-wh-type-color-drifter)',
  'eve-wh-type-color-zarzakh': 'var(--eve-wh-type-color-zarzakh)',
  // eve-kind-color-abyss and eve-kind-color-penalty both resolve to --eve-wh-type-color-c6
  'eve-kind-color-abyss': 'var(--eve-wh-type-color-c6)',
  'eve-kind-color-penalty': 'var(--eve-wh-type-color-c6)',
};

const DEFAULT_FILL = '#833ca4';

export function resolveSignatureFillVar(
  signature: SystemSignature,
  wormholesData: Record<string, WormholeDataRaw>,
): string {
  const customInfo = parseSignatureCustomInfo(signature.custom_info);

  // K162 override: use the k162Type to look up the real destination class
  if (signature.type === 'K162' && customInfo.k162Type) {
    const k162Option = K162_TYPES_MAP[customInfo.k162Type];
    if (k162Option) {
      const k162Data = wormholesData[k162Option.whClassName];
      const k162Class = k162Data ? WORMHOLES_ADDITIONAL_INFO[k162Data.dest] : null;
      if (k162Class) {
        const className = WORMHOLE_CLASS_STYLES[k162Class.wormholeClassID];
        if (className && CLASS_NAME_TO_CSS_VAR[className]) {
          return CLASS_NAME_TO_CSS_VAR[className];
        }
      }
    }
    return DEFAULT_FILL;
  }

  // Normal type lookup
  const whData = wormholesData[signature.type];
  if (!whData) return DEFAULT_FILL;

  const whClass = WORMHOLES_ADDITIONAL_INFO[whData.dest];
  if (!whClass) return DEFAULT_FILL;

  const className = WORMHOLE_CLASS_STYLES[whClass.wormholeClassID];
  if (!className) return DEFAULT_FILL;

  return CLASS_NAME_TO_CSS_VAR[className] || DEFAULT_FILL;
}
