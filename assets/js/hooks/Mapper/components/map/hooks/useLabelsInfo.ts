import { useMemo } from 'react';
import { LabelsManager } from '@/hooks/Mapper/utils/labelsManager';
import { getLabelDefinition, SystemLabelDefinition } from '@/hooks/Mapper/constants/labels';
import { useMapRootState } from '@/hooks/Mapper/mapRootProvider';

interface UseLabelsInfoParams {
  labels: string | null;
  linkedSigPrefix: string | null;
  isShowLinkedSigId: boolean;
}

export type LabelInfo = SystemLabelDefinition;

/**
 * Label ids are shared map data, label definitions are per user - ids without a definition
 * are still rendered, just with their raw id and a neutral color.
 */
function sortedLabels(labelIds: string[], definitions: SystemLabelDefinition[]): LabelInfo[] {
  if (!labelIds) return [];

  const ids = labelIds.filter(id => id.trim() !== '');

  const known = definitions.filter(x => ids.includes(x.id));
  const unknown = ids.filter(id => !definitions.some(x => x.id === id)).map(id => getLabelDefinition([], id));

  return [...known, ...unknown];
}

export function useLabelsInfo({ labels, linkedSigPrefix, isShowLinkedSigId }: UseLabelsInfoParams) {
  const {
    userRemoteSettings: { systemLabels },
  } = useMapRootState();

  const labelsManager = useMemo(() => new LabelsManager(labels ?? ''), [labels]);
  const labelsInfo = useMemo(() => sortedLabels(labelsManager.list, systemLabels), [labelsManager, systemLabels]);
  const labelCustom = useMemo(() => {
    if (isShowLinkedSigId && linkedSigPrefix) {
      return labelsManager.customLabel ? `${linkedSigPrefix}・${labelsManager.customLabel}` : linkedSigPrefix;
    }
    return labelsManager.customLabel;
  }, [linkedSigPrefix, isShowLinkedSigId, labelsManager]);

  return { labelsInfo, labelCustom };
}
