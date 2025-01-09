import { useMemo } from 'react';

import { useMapRootState } from '@/hooks/Mapper/mapRootProvider';
import { useMapGetOption } from '@/hooks/Mapper/mapRootProvider/hooks/api';
import { useMapState } from '@/hooks/Mapper/components/map/MapProvider';
import { useDoubleClick } from '@/hooks/Mapper/hooks/useDoubleClick';
import { REGIONS_MAP, Spaces } from '@/hooks/Mapper/constants';
import { isWormholeSpace } from '@/hooks/Mapper/components/map/helpers/isWormholeSpace';
import { getSystemClassStyles, prepareUnsplashedChunks } from '@/hooks/Mapper/components/map/helpers';
import { sortWHClasses } from '@/hooks/Mapper/helpers';
import { LabelsManager } from '@/hooks/Mapper/utils/labelsManager';
import { OutCommand } from '@/hooks/Mapper/types';
import { LABELS_INFO, LABELS_ORDER } from '@/hooks/Mapper/components/map/constants';

function getActivityType(count: number) {
  if (count <= 5) return 'activityNormal';
  if (count <= 30) return 'activityWarn';
  return 'activityDanger';
}

const SpaceToClass: Record<string, string> = {
  [Spaces.Caldari]: 'Caldaria',
  [Spaces.Matar]: 'Mataria',
  [Spaces.Amarr]: 'Amarria',
  [Spaces.Gallente]: 'Gallente',
};

function sortedLabels(labels: string[]) {
  if (!labels) return [];
  return LABELS_ORDER.filter(x => labels.includes(x)).map(x => LABELS_INFO[x]);
}

export function useSolarSystemNode(props: any) {
  const { data, selected, id } = props;
  const { system_static_info, system_signatures, locked, name, tag, status, labels, temporary_name } = data;

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
  } = system_static_info;

  // Global map state
  const { interfaceSettings } = useMapRootState();
  const { isShowUnsplashedSignatures } = interfaceSettings;
  const isTempSystemNameEnabled = useMapGetOption('show_temp_system_name') === 'true';

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

  // logic
  const visible = useMemo(() => visibleNodes.has(id), [id, visibleNodes]);

  const charactersInSystem = useMemo(() => {
    return characters.filter(c => c.location?.solar_system_id === solar_system_id).filter(c => c.online);
    // eslint-disable-next-line
  }, [characters, presentCharacters, solar_system_id]);

  const isWormhole = isWormholeSpace(system_class);

  const classTitleColor = useMemo(
    () => getSystemClassStyles({ systemClass: system_class, security }),
    [security, system_class],
  );

  const sortedStatics = useMemo(() => sortWHClasses(wormholesData, statics), [wormholesData, statics]);
  
  const labelsManager = useMemo(() => new LabelsManager(labels ?? ''), [labels]);
  const labelsInfo = useMemo(() => sortedLabels(labelsManager.list), [labelsManager]);
  const labelCustom = useMemo(() => labelsManager.customLabel, [labelsManager]);

  const killsCount = useMemo(() => kills[solar_system_id] ?? null, [kills, solar_system_id]);
  const killsActivityType = killsCount ? getActivityType(killsCount) : null;

  const hasUserCharacters = useMemo(() => {
    return charactersInSystem.some(x => userCharacters.includes(x.eve_id));
  }, [charactersInSystem, userCharacters]);

  const dbClick = useDoubleClick(() => {
    outCommand({
      type: OutCommand.openSettings,
      data: { system_id: solar_system_id.toString() },
    });
  });

  const showHandlers = isConnecting || hoverNodeId === id;

  const space = showKSpaceBG ? REGIONS_MAP[region_id] : '';
  const regionClass = showKSpaceBG ? SpaceToClass[space] : null;

  const systemName = (isTempSystemNameEnabled && temporary_name) || solar_system_name;
  const customName =
    (isTempSystemNameEnabled && temporary_name && name) || (solar_system_name !== name && name);

  const [unsplashedLeft, unsplashedRight] = useMemo(() => {
    if (!isShowUnsplashedSignatures) {
      return [[], []];
    }
    return prepareUnsplashedChunks(
      system_signatures
        .filter(s => s.group === 'Wormhole' && !s.linked_system)
        .map(s => ({
          eve_id: s.eve_id,
          type: s.type,
          custom_info: s.custom_info,
        })),
    );
  }, [isShowUnsplashedSignatures, system_signatures]);

  const nodeVars = {
    // original props
    selected,
    // computed
    visible,
    isWormhole,
    classTitleColor,
    killsCount,
    killsActivityType,
    hasUserCharacters,
    showHandlers,
    regionClass,
    systemName,
    customName,
    labelCustom,
    isShattered: is_shattered,
    tag,
    status,
    labelsInfo,
    dbClick,
    sortedStatics,
    effectName: effect_name,
    regionName: region_name,
    solarSystemId: solar_system_id,
    locked,
    hubs,
    charactersInSystem,
    unsplashedLeft,
    unsplashedRight,
    isThickConnections,
    classTitle: class_title,
  };

  return nodeVars;
}
