// feel free to rename these imports or the file path as you see fit
import { useMemo } from 'react';
import { useMapRootState } from '@/hooks/Mapper/mapRootProvider';
import { useMapGetOption } from '@/hooks/Mapper/mapRootProvider/hooks/api';
import { useMapState } from '@/hooks/Mapper/components/map/MapProvider.tsx';
import { useDoubleClick } from '@/hooks/Mapper/hooks/useDoubleClick.ts';
import { REGIONS_MAP, Spaces } from '@/hooks/Mapper/constants';
import { MapSolarSystemType } from '../../map.types';
import { LABELS_INFO, LABELS_ORDER, getActivityType } from '@/hooks/Mapper/components/map/constants.ts';
import { isWormholeSpace } from '@/hooks/Mapper/components/map/helpers/isWormholeSpace.ts';
import { getSystemClassStyles, prepareUnsplashedChunks } from '@/hooks/Mapper/components/map/helpers';
import { sortWHClasses } from '@/hooks/Mapper/helpers';
import { LabelsManager } from '@/hooks/Mapper/utils/labelsManager.ts';
import { OutCommand } from '@/hooks/Mapper/types';

const SpaceToClass: Record<string, string> = {
  [Spaces.Caldari]: 'Caldaria',
  [Spaces.Matar]: 'Mataria',
  [Spaces.Amarr]: 'Amarria',
  [Spaces.Gallente]: 'Gallente',
};

const sortedLabels = (labels: string[]) => {
  if (!labels) return [];
  return LABELS_ORDER.filter(x => labels.includes(x)).map(x => LABELS_INFO[x]);
};

interface UseSolarSystemNodeParams {
  data: MapSolarSystemType;
  selected: boolean;
}

export function useSolarSystemNode({ data, selected }: UseSolarSystemNodeParams) {
  // 1) Bring in relevant global state
  const { interfaceSettings } = useMapRootState();
  const { isShowUnsplashedSignatures } = interfaceSettings;
  const isTempSystemNameEnabled = useMapGetOption('show_temp_system_name') === 'true';
  const isShowLinkedSigId = useMapGetOption('show_linked_signature_id') === 'true';

  const {
    data: {
      characters,
      presentCharacters,
      wormholesData,
      hubs,
      kills,
      userCharacters,
      isConnecting,
      hoverNodeId,
      visibleNodes,
      showKSpaceBG,
      isThickConnections,
    },
    outCommand,
  } = useMapState();

  // 2) Extract data from the node
  const {
    system_class,
    security,
    class_title,
    solar_system_id,
    statics,
    effect_name,
    region_name,
    region_id,
    is_shattered,
    solar_system_name,
  } = data.system_static_info;

  const {
    locked,
    name,
    tag,
    status,
    labels,
    id,
    temporary_name: temporaryName,
    linked_sig_eve_id: linkedSigEveId = '',
  } = data || {};
  const signatures = data.system_signatures;

  // 3) Compute derived values
  const visible = useMemo(() => visibleNodes.has(id), [id, visibleNodes]);

  const charactersInSystem = useMemo(() => {
    return characters.filter(c => c.location?.solar_system_id === solar_system_id).filter(c => c.online);
  }, [characters, presentCharacters, solar_system_id]);

  const isWormhole = isWormholeSpace(system_class);

  const classTitleColor = useMemo(
    () => getSystemClassStyles({ systemClass: system_class, security }),
    [security, system_class],
  );

  const sortedStatics = useMemo(() => sortWHClasses(wormholesData, statics), [wormholesData, statics]);

  const linkedSigPrefix = useMemo(() => (linkedSigEveId ? linkedSigEveId.split('-')[0] : null), [linkedSigEveId]);

  const labelsManager = useMemo(() => new LabelsManager(labels ?? ''), [labels]);
  const labelsInfo = useMemo(() => sortedLabels(labelsManager.list), [labelsManager]);
  const labelCustom = useMemo(
    () =>
      isShowLinkedSigId && linkedSigPrefix
        ? `${linkedSigPrefix}・${labelsManager.customLabel}`
        : labelsManager.customLabel,
    [linkedSigPrefix, isShowLinkedSigId, labelsManager],
  );

  const killsCount = useMemo(() => {
    const systemKills = kills[solar_system_id];
    if (!systemKills) return null;
    return systemKills;
  }, [kills, solar_system_id]);

  const hasUserCharacters = useMemo(() => {
    return charactersInSystem.some(x => userCharacters.includes(x.eve_id));
  }, [charactersInSystem, userCharacters]);

  const dbClick = useDoubleClick(() => {
    outCommand({
      type: OutCommand.openSettings,
      data: {
        system_id: solar_system_id.toString(),
      },
    });
  });

  const showHandlers = isConnecting || hoverNodeId === id;

  const space = showKSpaceBG ? REGIONS_MAP[region_id] : '';
  const regionClass = showKSpaceBG ? SpaceToClass[space] : null;

  const systemName = (isTempSystemNameEnabled && temporaryName) || solar_system_name;
  const customName = (isTempSystemNameEnabled && temporaryName && name) || (solar_system_name !== name && name);

  const [unsplashedLeft, unsplashedRight] = useMemo(() => {
    if (!isShowUnsplashedSignatures) {
      return [[], []];
    }
    return prepareUnsplashedChunks(
      signatures
        .filter(s => s.group === 'Wormhole' && !s.linked_system)
        .map(s => ({
          eve_id: s.eve_id,
          type: s.type,
          custom_info: s.custom_info,
        })),
    );
  }, [isShowUnsplashedSignatures, signatures]);

  return {
    selected,
    visible,
    isWormhole,
    classTitleColor,
    killsCount,
    hasUserCharacters,
    showHandlers,
    regionClass,
    systemName,
    customName,
    labelCustom,
    is_shattered,
    tag,
    status,
    labelsInfo,
    dbClick,
    sortedStatics,
    effect_name,
    region_name,
    solar_system_id,
    locked,
    hubs,
    charactersInSystem,
    unsplashedLeft,
    unsplashedRight,
    isThickConnections,
  };
}
