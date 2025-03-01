import { useMemo } from 'react';
import { LabelsManager } from '@/hooks/Mapper/utils/labelsManager';
import { LABELS_INFO, LABELS_ORDER } from '@/hooks/Mapper/components/map/constants';
interface UseLabelsInfoParams {
  labels: string | null;
  linkedSigPrefix: string | null;
  isShowLinkedSigId: boolean;
}

export type LabelInfo = {
  id: string;
  shortName: string;
};

function sortedLabels(labels: string[]): LabelInfo[] {
  if (!labels) return [];
  return LABELS_ORDER.filter(x => labels.includes(x)).map(x => LABELS_INFO[x] as LabelInfo);
}

export function useLabelsInfo({ labels, linkedSigPrefix, isShowLinkedSigId }: UseLabelsInfoParams) {
  const labelsManager = useMemo(() => new LabelsManager(labels ?? ''), [labels]);
  const labelsInfo = useMemo(() => sortedLabels(labelsManager.list), [labelsManager]);
  const labelCustom = useMemo(() => {
    if (isShowLinkedSigId && linkedSigPrefix) {
      return labelsManager.customLabel ? `${linkedSigPrefix}・${labelsManager.customLabel}` : linkedSigPrefix;
    }
    return labelsManager.customLabel;
  }, [linkedSigPrefix, isShowLinkedSigId, labelsManager]);

  return { labelsInfo, labelCustom };
}
