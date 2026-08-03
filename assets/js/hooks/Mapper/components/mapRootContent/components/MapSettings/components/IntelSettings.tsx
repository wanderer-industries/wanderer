import { useMapRootState } from '@/hooks/Mapper/mapRootProvider';
import { useCallback, useEffect, useMemo, useState } from 'react';
import { OutCommand, UserPermission } from '@/hooks/Mapper/types';
import { useMapCheckPermissions } from '@/hooks/Mapper/mapRootProvider/hooks/api';
import { Dropdown } from 'primereact/dropdown';
import { WdButton } from '@/hooks/Mapper/components/ui-kit';

interface IntelSourceMap {
  id: string;
  name: string;
  slug: string;
}

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
      } catch (error) {
        console.error('Failed to load intel source maps:', error);
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
      setSelectedMapId(mapId);
      try {
        await outCommand({
          type: OutCommand.setIntelSourceMap,
          data: { intel_source_map_id: mapId },
        });
      } catch (error) {
        console.error('Failed to update intel source map:', error);
        setSelectedMapId(options?.intel_source_map_id ?? null);
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
