import { useMemo } from 'react';
import { MapSolarSystemType } from '../map.types';
import { NodeProps } from 'reactflow';
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

export function useSolarSystemNode(props: NodeProps<MapSolarSystemType>) {
  const { id, data, selected } = props;
  const {
    system_static_info,
    system_signatures,
    locked,
    name,
    tag,
    status,
    labels,
    temporary_name,
    linked_sig_eve_id: linkedSigEveId = '',
  } = data;

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

  const {
    interfaceSettings,
    data: { systemSignatures: mapSystemSignatures },
  } = useMapRootState();

  const { isShowUnsplashedSignatures } = interfaceSettings;
  const isTempSystemNameEnabled = useMapGetOption('show_temp_system_name') === 'true';
  const isShowLinkedSigId = useMapGetOption('show_linked_signature_id') === 'true';
  const isShowLinkedSigIdTempName = useMapGetOption('show_linked_signature_id_temp_name') === 'true';

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

  const visible = useMemo(() => visibleNodes.has(id), [id, visibleNodes]);

  const systemSignatures = useMemo(
    () => mapSystemSignatures[solar_system_id] || system_signatures,
    [system_signatures, solar_system_id, mapSystemSignatures],
  );

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

  const linkedSigPrefix = useMemo(() => (linkedSigEveId ? linkedSigEveId.split('-')[0] : null), [linkedSigEveId]);

  const labelsManager = useMemo(() => new LabelsManager(labels ?? ''), [labels]);
  const labelsInfo = useMemo(() => sortedLabels(labelsManager.list), [labelsManager]);
  const labelCustom = useMemo(() => {
    if (isShowLinkedSigId && linkedSigPrefix) {
      return labelsManager.customLabel ? `${linkedSigPrefix}・${labelsManager.customLabel}` : linkedSigPrefix;
    }
    return labelsManager.customLabel;
  }, [linkedSigPrefix, isShowLinkedSigId, labelsManager]);

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

  const temporaryName = useMemo(() => {
    if (!isTempSystemNameEnabled) {
      return '';
    }

    if (isShowLinkedSigIdTempName && linkedSigPrefix) {
      return temporary_name ? `${linkedSigPrefix}・${temporary_name}` : `${linkedSigPrefix}・${solar_system_name}`;
    }

    return temporary_name;
  }, [isShowLinkedSigIdTempName, isTempSystemNameEnabled, linkedSigPrefix, solar_system_name, temporary_name]);

  const systemName = useMemo(() => {
    if (isTempSystemNameEnabled && temporaryName) {
      return temporaryName;
    }
    return solar_system_name;
  }, [isTempSystemNameEnabled, solar_system_name, temporaryName]);

  const customName = (isTempSystemNameEnabled && temporary_name && name) || (solar_system_name !== name && name);

  const [unsplashedLeft, unsplashedRight] = useMemo(() => {
    if (!isShowUnsplashedSignatures) {
      return [[], []];
    }
    return prepareUnsplashedChunks(
      systemSignatures
        .filter(s => s.group === 'Wormhole' && !s.linked_system)
        .map(s => ({
          eve_id: s.eve_id,
          type: s.type,
          custom_info: s.custom_info,
        })),
    );
  }, [isShowUnsplashedSignatures, systemSignatures]);

  const nodeVars = {
    id,
    selected,

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
    solarSystemName: solar_system_name,
    locked,
    hubs,
    name: name,
    isConnecting,
    hoverNodeId,
    charactersInSystem,
    unsplashedLeft,
    unsplashedRight,
    isThickConnections,
    classTitle: class_title,
    temporaryName: temporary_name,
  };

  return nodeVars;
}
