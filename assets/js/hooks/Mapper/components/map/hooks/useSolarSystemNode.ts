import { useMemo } from 'react';
import { MapSolarSystemType } from '../map.types';
import { NodeProps } from 'reactflow';
import { useMapRootState } from '@/hooks/Mapper/mapRootProvider';
import { useMapGetOption } from '@/hooks/Mapper/mapRootProvider/hooks/api';
import { useMapState } from '@/hooks/Mapper/components/map/MapProvider';
import { useDoubleClick } from '@/hooks/Mapper/hooks/useDoubleClick';
import { Regions, REGIONS_MAP, SPACE_TO_CLASS } from '@/hooks/Mapper/constants';
import { isWormholeSpace } from '@/hooks/Mapper/components/map/helpers/isWormholeSpace';
import { getSystemClassStyles } from '@/hooks/Mapper/components/map/helpers';
import { sortWHClasses } from '@/hooks/Mapper/helpers';
import { CharacterTypeRaw, OutCommand, PingType, SystemSignature } from '@/hooks/Mapper/types';
import { useUnsplashedSignatures } from './useUnsplashedSignatures';
import { useSystemName } from './useSystemName';
import { LabelInfo, useLabelsInfo } from './useLabelsInfo';
import { getSystemStaticInfo } from '@/hooks/Mapper/mapRootProvider/hooks/useLoadSystemStatic';

export interface SolarSystemNodeVars {
  id: string;
  selected: boolean;
  visible: boolean;
  isWormhole: boolean;
  classTitleColor: string | null;
  hasUserCharacters: boolean;
  showHandlers: boolean;
  regionClass: string | null;
  systemName: string;
  customName?: string | null;
  labelCustom: string | null;
  isShattered: boolean;
  tag?: string | null;
  status?: number;
  labelsInfo: LabelInfo[];
  dbClick: (event: React.MouseEvent<HTMLDivElement>) => void;
  sortedStatics: Array<string | number>;
  effectName: string | null;
  regionName: string | null;
  solarSystemId: string;
  solarSystemName: string | null;
  locked: boolean;
  hubs: string[];
  name: string | null;
  isConnecting: boolean;
  hoverNodeId: string | null;
  charactersInSystem: Array<CharacterTypeRaw>;
  userCharacters: string[];
  unsplashedLeft: Array<SystemSignature>;
  unsplashedRight: Array<SystemSignature>;
  isThickConnections: boolean;
  isRally: boolean;
  classTitle: string | null;
  temporaryName?: string | null;
  description: string | null;
  comments_count: number | null;
  systemHighlighted: string | undefined;
}

export const useSolarSystemNode = (props: NodeProps<MapSolarSystemType>): SolarSystemNodeVars => {
  const { id, data, selected } = props;
  const {
    id: solar_system_id,
    locked,
    name,
    tag,
    status,
    labels,
    temporary_name,
    linked_sig_eve_id: linkedSigEveId = '',
    description,
    comments_count,
  } = data;

  const {
    storedSettings: { interfaceSettings },
    data: { systemSignatures: mapSystemSignatures },
  } = useMapRootState();

  const systemStaticInfo = useMemo(() => {
    return getSystemStaticInfo(solar_system_id)!;
  }, [solar_system_id]);

  const {
    system_class,
    security,
    class_title,
    statics,
    effect_name,
    region_name,
    region_id,
    is_shattered,
    solar_system_name,
    constellation_name,
  } = systemStaticInfo;

  const { isShowUnsplashedSignatures } = interfaceSettings;
  const isTempSystemNameEnabled = useMapGetOption('show_temp_system_name') === 'true';
  const isShowLinkedSigId = useMapGetOption('show_linked_signature_id') === 'true';
  const isShowLinkedSigIdTempName = useMapGetOption('show_linked_signature_id_temp_name') === 'true';

  const {
    data: {
      characters,
      wormholesData,
      hubs,
      userCharacters,
      isConnecting,
      hoverNodeId,
      visibleNodes,
      showKSpaceBG,
      isThickConnections,
      pings,
      systemHighlighted,
    },
    outCommand,
  } = useMapState();

  const visible = useMemo(() => visibleNodes.has(id), [id, visibleNodes]);

  const systemSigs = useMemo(() => mapSystemSignatures[solar_system_id] || [], [solar_system_id, mapSystemSignatures]);

  const charactersInSystem = useMemo(() => {
    return characters.filter(c => c.location?.solar_system_id === parseInt(solar_system_id) && c.online);
  }, [characters, solar_system_id]);

  const isWormhole = isWormholeSpace(system_class);

  const classTitleColor = useMemo(
    () => getSystemClassStyles({ systemClass: system_class, security }),
    [security, system_class],
  );

  const sortedStatics = useMemo(() => sortWHClasses(wormholesData, statics), [wormholesData, statics]);

  const linkedSigPrefix = useMemo(() => (linkedSigEveId ? linkedSigEveId.split('-')[0] : null), [linkedSigEveId]);

  const { labelsInfo, labelCustom } = useLabelsInfo({
    labels,
    linkedSigPrefix,
    isShowLinkedSigId,
  });

  const hasUserCharacters = useMemo(
    () => charactersInSystem.some(x => userCharacters.includes(x.eve_id)),
    [charactersInSystem, userCharacters],
  );

  const dbClick = useDoubleClick(() => {
    outCommand({
      type: OutCommand.openSettings,
      data: { system_id: solar_system_id },
    });
  });

  const showHandlers = isConnecting || hoverNodeId === id;

  const space = showKSpaceBG ? REGIONS_MAP[region_id] : '';
  const regionClass = showKSpaceBG ? SPACE_TO_CLASS[space] || null : null;

  const { systemName, computedTemporaryName, customName } = useSystemName({
    isTempSystemNameEnabled,
    temporary_name,
    isShowLinkedSigIdTempName,
    linkedSigPrefix,
    name,
    systemStaticInfo,
  });

  const { unsplashedLeft, unsplashedRight } = useUnsplashedSignatures(systemSigs, isShowUnsplashedSignatures);

  const hubsAsStrings = useMemo(() => hubs.map(item => item.toString()), [hubs]);

  const isRally = useMemo(
    () => !!pings.find(x => x.solar_system_id === solar_system_id && x.type === PingType.Rally),
    [pings, solar_system_id],
  );

  const regionName = useMemo(() => {
    if (region_id === Regions.Pochven) {
      return constellation_name;
    }

    return region_name;
  }, [constellation_name, region_id, region_name]);

  const nodeVars: SolarSystemNodeVars = {
    id,
    selected,
    visible,
    isWormhole,
    classTitleColor,
    hasUserCharacters,
    userCharacters,
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
    solarSystemId: solar_system_id.toString(),
    locked,
    hubs: hubsAsStrings,
    name,
    isConnecting,
    hoverNodeId,
    charactersInSystem,
    unsplashedLeft,
    unsplashedRight,
    isThickConnections,
    classTitle: class_title,
    temporaryName: computedTemporaryName,
    regionName,
    solarSystemName: solar_system_name,
    isRally,
    description,
    comments_count,
    systemHighlighted,
  };

  return nodeVars;
};
