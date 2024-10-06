import { useMapRootState } from '@/hooks/Mapper/mapRootProvider';
import { useClipboard } from '@/hooks/Mapper/hooks/useClipboard';
import { parseSignatures } from '@/hooks/Mapper/helpers';
import { OutCommand } from '@/hooks/Mapper/types/mapHandlers.ts';
import { WdTooltip, WdTooltipHandlers } from '@/hooks/Mapper/components/ui-kit';

import { DataTable, DataTableRowMouseEvent, SortOrder } from 'primereact/datatable';
import { Column } from 'primereact/column';
import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import useRefState from 'react-usestateref';
import { Setting } from '../SystemSignatureSettingsDialog';
import { useHotkey } from '@/hooks/Mapper/hooks';
import useMaxWidth from '@/hooks/Mapper/hooks/useMaxWidth.ts';

import classes from './SystemSignaturesContent.module.scss';
import clsx from 'clsx';
import { SystemSignature } from '@/hooks/Mapper/types';
import { SignatureView } from '@/hooks/Mapper/components/mapInterface/widgets/SystemSignatures/SignatureView';
import {
  getActualSigs,
  getRowColorByTimeLeft,
} from '@/hooks/Mapper/components/mapInterface/widgets/SystemSignatures/helpers';
import {
  renderIcon,
  renderName,
  renderTimeLeft,
} from '@/hooks/Mapper/components/mapInterface/widgets/SystemSignatures/renders';
import useLocalStorageState from 'use-local-storage-state';

type SystemSignaturesSortSettings = {
  sortField: string;
  sortOrder: SortOrder;
}

const SORT_DEFAULT_VALUES: SystemSignaturesSortSettings = {
  sortField: 'eve_id',
  sortOrder: 1
};

interface SystemSignaturesContentProps {
  systemId: string;
  settings: Setting[];
}
export const SystemSignaturesContent = ({ systemId, settings }: SystemSignaturesContentProps) => {
  const { outCommand } = useMapRootState();

  const [signatures, setSignatures, signaturesRef] = useRefState<SystemSignature[]>([]);
  const [selectedSignatures, setSelectedSignatures] = useState<SystemSignature[]>([]);
  const [nameColumnWidth, setNameColumnWidth] = useState('auto');

  const [hoveredSig, setHoveredSig] = useState<SystemSignature | null>(null);

  const [sortSettings, setSortSettings] = useLocalStorageState<SystemSignaturesSortSettings>('window:signatures:sort', {
    defaultValue: SORT_DEFAULT_VALUES,
  });

  const tableRef = useRef<HTMLDivElement>(null);
  const compact = useMaxWidth(tableRef, 260);
  const medium = useMaxWidth(tableRef, 380);

  const tooltipRef = useRef<WdTooltipHandlers>(null);

  const { clipboardContent } = useClipboard();

  const handleResize = useCallback(() => {
    if (tableRef.current) {
      const tableWidth = tableRef.current.offsetWidth;
      const otherColumnsWidth = 265;
      const availableWidth = tableWidth - otherColumnsWidth;
      setNameColumnWidth(`${availableWidth}px`);
    }
  }, []);

  const filteredSignatures = useMemo(() => {
    return signatures
      .filter(x => settings.find(y => y.key === x.kind)?.value)
      .sort((a, b) => {
        return new Date(b.updated_at || 0).getTime() - new Date(a.updated_at || 0).getTime();
      });
  }, [signatures, settings]);

  const handleGetSignatures = useCallback(async () => {
    const { signatures } = await outCommand({
      type: OutCommand.getSignatures,
      data: { system_id: systemId },
    });

    setSignatures(signatures);
  }, [outCommand, systemId]);

  const handleUpdateSignatures = useCallback(
    async (newSignatures: SystemSignature[]) => {
      const { added, updated, removed } = getActualSigs(signaturesRef.current, newSignatures);

      const { signatures: updatedSignatures } = await outCommand({
        type: OutCommand.updateSignatures,
        data: {
          system_id: systemId,
          added,
          updated,
          removed,
        },
      });

      setSignatures(() => updatedSignatures);
      setSelectedSignatures([]);
    },
    [outCommand, systemId],
  );

  const handleDeleteSelected = useCallback(async () => {
    if (selectedSignatures.length === 0) {
      return;
    }
    const selectedSignaturesEveIds = selectedSignatures.map(x => x.eve_id);
    await handleUpdateSignatures(signatures.filter(x => !selectedSignaturesEveIds.includes(x.eve_id)));
  }, [handleUpdateSignatures, signatures, selectedSignatures]);

  const handleSelectAll = useCallback(() => {
    setSelectedSignatures(signatures);
  }, [signatures]);

  useHotkey(true, ['a'], handleSelectAll);

  useHotkey(false, ['Backspace', 'Delete'], handleDeleteSelected);

  useEffect(() => {
    if (!clipboardContent) {
      return;
    }

    const signatures = parseSignatures(
      clipboardContent,
      settings.map(x => x.key),
    );

    handleUpdateSignatures(signatures);
  }, [clipboardContent]);

  useEffect(() => {
    if (!systemId) {
      setSignatures([]);
      return;
    }

    handleGetSignatures();
  }, [systemId]);

  useEffect(() => {
    const observer = new ResizeObserver(handleResize);
    if (tableRef.current) {
      observer.observe(tableRef.current);
    }

    handleResize(); // Call on mount to set initial width

    return () => {
      if (tableRef.current) {
        observer.unobserve(tableRef.current);
      }
    };
  }, []);

  const handleEnterRow = useCallback(
    (e: DataTableRowMouseEvent) => {
      setHoveredSig(filteredSignatures[e.index]);
      tooltipRef.current?.show(e.originalEvent);
    },
    [filteredSignatures],
  );

  const handleLeaveRow = useCallback((e: DataTableRowMouseEvent) => {
    tooltipRef.current?.hide(e.originalEvent);
    setHoveredSig(null);
  }, []);

  return (
    <div ref={tableRef} className="h-full">
      {filteredSignatures.length === 0 ? (
        <div className="w-full h-full flex justify-center items-center select-none text-stone-400/80 text-sm">
          No signatures
        </div>
      ) : (
        <>
          <DataTable
            value={filteredSignatures}
            size="small"
            selectionMode="multiple"
            selection={selectedSignatures}
            onSelectionChange={e => setSelectedSignatures(e.value)}
            dataKey="eve_id"
            tableClassName="w-full select-none"
            resizableColumns
            rowHover
            selectAll
            sortField={sortSettings.sortField}
            sortOrder={sortSettings.sortOrder}
            onSort={(event) => setSortSettings(() => ({ sortField: event.sortField, sortOrder: event.sortOrder }))}
            onRowMouseEnter={handleEnterRow}
            onRowMouseLeave={handleLeaveRow}
            rowClassName={row => {
              if (selectedSignatures.some(x => x.eve_id === row.eve_id)) {
                return clsx(classes.TableRowCompact, 'bg-amber-500/50 hover:bg-amber-500/70 transition duration-200');
              }

              const dateClass = getRowColorByTimeLeft(row.updated_at ? new Date(row.updated_at) : undefined);
              if (!dateClass) {
                return clsx(classes.TableRowCompact, 'hover:bg-purple-400/20 transition duration-200');
              }

              return clsx(classes.TableRowCompact, dateClass);
            }}
          >
            <Column
              bodyClassName="p-0 px-1"
              field="group"
              body={renderIcon}
              style={{ maxWidth: 26, minWidth: 26, width: 26 }}
            ></Column>

            <Column
              field="eve_id"
              header="Id"
              bodyClassName="text-ellipsis overflow-hidden whitespace-nowrap"
              style={{ maxWidth: 72, minWidth: 72, width: 72 }}
              sortable
            ></Column>
            <Column
              field="group"
              header="Group"
              bodyClassName="text-ellipsis overflow-hidden whitespace-nowrap"
              hidden={compact}
              sortable
            ></Column>
            <Column
              field="name"
              header="Name"
              bodyClassName="text-ellipsis overflow-hidden whitespace-nowrap"
              body={renderName}
              style={{ maxWidth: nameColumnWidth }}
              hidden={compact || medium}
              sortable
            ></Column>
            <Column
              field="updated_at"
              header="Updated"
              dataType="date"
              bodyClassName="w-[80px] text-ellipsis overflow-hidden whitespace-nowrap"
              body={renderTimeLeft}
              sortable
            ></Column>
          </DataTable>
        </>
      )}
      <WdTooltip
        className="bg-stone-900/95 text-slate-50"
        ref={tooltipRef}
        content={hoveredSig ? <SignatureView {...hoveredSig} /> : null}
      />
    </div>
  );
};
