import { useMapRootState } from '@/hooks/Mapper/mapRootProvider';
import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { OutCommand, UserPermission } from '@/hooks/Mapper/types';
import { useMapCheckPermissions } from '@/hooks/Mapper/mapRootProvider/hooks/api';
import { Dropdown } from 'primereact/dropdown';
import { Toast } from 'primereact/toast';
import { callToastError } from '@/hooks/Mapper/helpers';
import { WdButton } from '@/hooks/Mapper/components/ui-kit';

interface IntelSourceMap {
  id: string;
  name: string;
  slug: string;
}

// The server refuses a selection rather than raising, so the reply carries a
// code instead of rejecting the promise. Anything unlisted falls back to the
// generic message.
const ERROR_MESSAGES: Record<string, string> = {
  circular_reference: 'That map already uses this map as its intel source.',
  source_is_subscriber: 'That map already inherits its intel from another map. Intel cannot be chained.',
  map_is_a_source: 'Another map already uses this map as its intel source. Intel cannot be chained.',
  unauthorized_source: 'You do not have access to that map.',
  forbidden: 'You do not have permission to change the intel source.',
};

export const IntelSettings = () => {
  const {
    outCommand,
    data: { options },
  } = useMapRootState();

  const isManager = useMapCheckPermissions([UserPermission.MANAGE_MAP]);
  const isAdmin = useMapCheckPermissions([UserPermission.ADMIN_MAP]);
  const hasPermission = isManager || isAdmin;

  const [availableMaps, setAvailableMaps] = useState<IntelSourceMap[]>([]);
  const [selectedMapId, setSelectedMapId] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);
  const toast = useRef<Toast | null>(null);

  useEffect(() => {
    let cancelled = false;

    const load = async () => {
      setLoading(true);
      try {
        const result = (await outCommand({
          type: OutCommand.getIntelSourceMaps,
          data: null,
        })) as { maps?: IntelSourceMap[] } | undefined;

        if (!cancelled && result?.maps) {
          setAvailableMaps(result.maps);
        }
      } catch {
        // Non-fatal: the dropdown stays empty and the user can retry.
      } finally {
        if (!cancelled) {
          setLoading(false);
        }
      }
    };

    if (hasPermission) {
      load();
    }

    return () => {
      cancelled = true;
    };
  }, [outCommand, hasPermission]);

  useEffect(() => {
    setSelectedMapId(options?.intel_source_map_id ?? null);
  }, [options?.intel_source_map_id]);

  const dropdownOptions = useMemo(() => availableMaps.map(m => ({ label: m.name, value: m.id })), [availableMaps]);

  const handleChange = useCallback(
    async (mapId: string | null) => {
      const previous = options?.intel_source_map_id ?? null;
      setSelectedMapId(mapId);

      let response: { success?: boolean; error?: string } | undefined;

      try {
        response = await outCommand({
          type: OutCommand.setIntelSourceMap,
          data: { intel_source_map_id: mapId },
        });
      } catch {
        // Revert the optimistic selection; the server keeps the old source.
        setSelectedMapId(previous);
        callToastError(toast.current, 'Something went wrong while setting the intel source');
        return;
      }

      if (response && response.success === false) {
        setSelectedMapId(previous);
        callToastError(toast.current, ERROR_MESSAGES[response.error ?? ''] ?? 'The intel source could not be changed');
      }
    },
    [outCommand, options?.intel_source_map_id],
  );

  const handleClear = useCallback(() => {
    handleChange(null);
  }, [handleChange]);

  if (!hasPermission) {
    return null;
  }

  return (
    <div className="flex flex-col gap-3">
      <Toast ref={toast} />
      <span className="text-stone-500 text-[12px]">
        Select a map to use as the intel source. System intel (custom names, labels, descriptions, status, comments,
        structures) will be copied from the source map when systems appear on this map.
      </span>

      {/* 1fr_auto grid: default `stretch` sizes Clear to the row, and py-0 keeps the
          dropdown (not the button) the taller item, so the row is the dropdown's height */}
      <div className="grid grid-cols-[1fr_auto] gap-2">
        <Dropdown
          value={selectedMapId}
          options={dropdownOptions}
          onChange={e => handleChange(e.value)}
          placeholder="Select intel source map"
          className="w-full"
          loading={loading}
          showClear={false}
        />

        <WdButton
          onClick={handleClear}
          icon="pi pi-times"
          size="small"
          severity="danger"
          label="Clear"
          className="py-0"
          disabled={!selectedMapId}
        />
      </div>
    </div>
  );
};
