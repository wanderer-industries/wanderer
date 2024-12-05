import { useMapRootState } from '@/hooks/Mapper/mapRootProvider';
import { parseSignatures } from '@/hooks/Mapper/helpers';
import { Commands, OutCommand } from '@/hooks/Mapper/types/mapHandlers.ts';
import { WdTooltip, WdTooltipHandlers } from '@/hooks/Mapper/components/ui-kit';
import { GROUPS_LIST } from '@/hooks/Mapper/components/mapInterface/widgets/SystemSignatures/constants.ts';

import { DataTable, DataTableRowClickEvent, DataTableRowMouseEvent, SortOrder } from 'primereact/datatable';
import { Column } from 'primereact/column';
import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import useRefState from 'react-usestateref';
import { Setting } from '../SystemSignatureSettingsDialog';
import { useHotkey } from '@/hooks/Mapper/hooks';
import useMaxWidth from '@/hooks/Mapper/hooks/useMaxWidth.ts';
import { useClipboard } from '@/hooks/Mapper/hooks/useClipboard';

import classes from './SystemSignaturesContent.module.scss';
import clsx from 'clsx';
import { SystemSignature } from '@/hooks/Mapper/types';
import { SignatureView } from '@/hooks/Mapper/components/mapInterface/widgets/SystemSignatures/SignatureView';
import {
  getActualSigs,
  getRowColorByTimeLeft,
} from '@/hooks/Mapper/components/mapInterface/widgets/SystemSignatures/helpers';
import {
  renderAddedTimeLeft,
  renderDescription,
  renderIcon,
  renderInfoColumn,
  renderUpdatedTimeLeft,
} from '@/hooks/Mapper/components/mapInterface/widgets/SystemSignatures/renders';
import useLocalStorageState from 'use-local-storage-state';
import { PrimeIcons } from 'primereact/api';
import { SignatureSettings } from '@/hooks/Mapper/components/mapRootContent/components/SignatureSettings';
import { useMapEventListener } from '@/hooks/Mapper/events';
import { WdTooltipWrapper } from '@/hooks/Mapper/components/ui-kit/WdTooltipWrapper';
import { COSMIC_SIGNATURE } from '@/hooks/Mapper/components/mapInterface/widgets/SystemSignatures/SystemSignatureSettingsDialog';
import {
  SHOW_DESCRIPTION_COLUMN_SETTING,
  SHOW_UPDATED_COLUMN_SETTING,
  LAZY_DELETE_SIGNATURES_SETTING,
  KEEP_LAZY_DELETE_SETTING,
} from '@/hooks/Mapper/components/mapInterface/widgets/SystemSignatures';
type SystemSignaturesSortSettings = {
  sortField: string;
  sortOrder: SortOrder;
};

const SORT_DEFAULT_VALUES: SystemSignaturesSortSettings = {
  sortField: 'inserted_at',
  sortOrder: -1,
};

interface SystemSignaturesContentProps {
  systemId: string;
  settings: Setting[];
  hideLinkedSignatures?: boolean;
  selectable?: boolean;
  onSelect?: (signature: SystemSignature) => void;
  onLazyDeleteChange?: (value: boolean) => void;
}
export const SystemSignaturesContent = ({
  systemId,
  settings,
  hideLinkedSignatures,
  selectable,
  onSelect,
  onLazyDeleteChange,
}: SystemSignaturesContentProps) => {
  const { outCommand } = useMapRootState();

  const [signatures, setSignatures, signaturesRef] = useRefState<SystemSignature[]>([]);
  const [selectedSignatures, setSelectedSignatures] = useState<SystemSignature[]>([]);
  const [nameColumnWidth, setNameColumnWidth] = useState('auto');
  const [selectedSignature, setSelectedSignature] = useState<SystemSignature | null>(null);

  const [hoveredSig, setHoveredSig] = useState<SystemSignature | null>(null);

  const [sortSettings, setSortSettings] = useLocalStorageState<SystemSignaturesSortSettings>('window:signatures:sort', {
    defaultValue: SORT_DEFAULT_VALUES,
  });

  const tableRef = useRef<HTMLDivElement>(null);
  const compact = useMaxWidth(tableRef, 260);
  const medium = useMaxWidth(tableRef, 380);
  const refData = useRef({ selectable });
  refData.current = { selectable };

  const tooltipRef = useRef<WdTooltipHandlers>(null);

  const { clipboardContent, setClipboardContent } = useClipboard();

  const lazyDeleteValue = useMemo(() => {
    return settings.find(setting => setting.key === LAZY_DELETE_SIGNATURES_SETTING)?.value ?? false;
  }, [settings]);

  const keepLazyDeleteValue = useMemo(() => {
    return settings.find(setting => setting.key === KEEP_LAZY_DELETE_SETTING)?.value ?? false;
  }, [settings]);

  const handleResize = useCallback(() => {
    if (tableRef.current) {
      const tableWidth = tableRef.current.offsetWidth;
      const otherColumnsWidth = 276;
      const availableWidth = tableWidth - otherColumnsWidth;
      setNameColumnWidth(`${availableWidth}px`);
    }
  }, []);

  const groupSettings = useMemo(() => settings.filter(s => (GROUPS_LIST as string[]).includes(s.key)), [settings]);
  const showDescriptionColumn = useMemo(
    () => settings.find(s => s.key === SHOW_DESCRIPTION_COLUMN_SETTING)?.value,
    [settings],
  );

  const showUpdatedColumn = useMemo(() => settings.find(s => s.key === SHOW_UPDATED_COLUMN_SETTING)?.value, [settings]);

  const filteredSignatures = useMemo(() => {
    return signatures
      .filter(x => {
        if (hideLinkedSignatures && !!x.linked_system) {
          return false;
        }

        const isCosmicSignature = x.kind === COSMIC_SIGNATURE;

        if (isCosmicSignature) {
          const showCosmicSignatures = settings.find(y => y.key === COSMIC_SIGNATURE)?.value;
          if (showCosmicSignatures) {
            return !x.group || groupSettings.find(y => y.key === x.group)?.value;
          } else {
            return !!x.group && groupSettings.find(y => y.key === x.group)?.value;
          }
        }

        return settings.find(y => y.key === x.kind)?.value;
      })
      .sort((a, b) => {
        return new Date(b.updated_at || 0).getTime() - new Date(a.updated_at || 0).getTime();
      });
  }, [signatures, settings, groupSettings, hideLinkedSignatures]);

  const handleGetSignatures = useCallback(async () => {
    const { signatures } = await outCommand({
      type: OutCommand.getSignatures,
      data: { system_id: systemId },
    });

    setSignatures(signatures);
  }, [outCommand, systemId]);

  const handleUpdateSignatures = useCallback(
    async (newSignatures: SystemSignature[], updateOnly: boolean, skipUpdateUntouched?: boolean) => {
      const { added, updated, removed } = getActualSigs(
        signaturesRef.current,
        newSignatures,
        updateOnly,
        skipUpdateUntouched,
      );

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

  const handleDeleteSelected = useCallback(
    async (e: KeyboardEvent) => {
      if (selectable) {
        return;
      }
      if (selectedSignatures.length === 0) {
        return;
      }

      e.preventDefault();
      e.stopPropagation();

      const selectedSignaturesEveIds = selectedSignatures.map(x => x.eve_id);
      await handleUpdateSignatures(
        signatures.filter(x => !selectedSignaturesEveIds.includes(x.eve_id)),
        false,
        true,
      );
    },
    [handleUpdateSignatures, selectable, signatures, selectedSignatures],
  );

  const handleSelectAll = useCallback(() => {
    setSelectedSignatures(signatures);
  }, [signatures]);

  const handleSelectSignatures = useCallback(
    // TODO still will be good to define types if we use typescript
    // @ts-ignore
    e => {
      if (selectable) {
        onSelect?.(e.value);
      } else {
        setSelectedSignatures(e.value);
      }
    },
    [onSelect, selectable],
  );

  const handlePaste = async (clipboardContent: string) => {
    const newSignatures = parseSignatures(
      clipboardContent,
      settings.map(x => x.key),
    );

    handleUpdateSignatures(newSignatures, !lazyDeleteValue);

    if (lazyDeleteValue && !keepLazyDeleteValue) {
      onLazyDeleteChange?.(false);
    }
  };

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

  useEffect(() => {
    if (refData.current.selectable) {
      return;
    }

    if (!clipboardContent?.text) {
      return;
    }

    handlePaste(clipboardContent.text);
    setClipboardContent(null);
  }, [clipboardContent, selectable, lazyDeleteValue, keepLazyDeleteValue]);

  useHotkey(true, ['a'], handleSelectAll);
  useHotkey(false, ['Backspace', 'Delete'], handleDeleteSelected);

  useEffect(() => {
    if (!systemId) {
      setSignatures([]);
      return;
    }

    handleGetSignatures();
  }, [systemId]);

  useMapEventListener(event => {
    switch (event.name) {
      case Commands.signaturesUpdated:
        if (event.data?.toString() !== systemId.toString()) {
          return;
        }

        handleGetSignatures();
        return true;
    }
  });

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

  const renderToolbar = (/*row: SystemSignature*/) => {
    return (
      <div className="flex justify-end items-center gap-2 mr-[4px]">
        <WdTooltipWrapper content="To Edit Signature do double click">
          <span className={clsx(PrimeIcons.PENCIL, 'text-[10px]')}></span>
        </WdTooltipWrapper>
      </div>
    );
  };

  const [showSignatureSettings, setShowSignatureSettings] = useState(false);

  const handleRowClick = (e: DataTableRowClickEvent) => {
    setSelectedSignature(e.data as SystemSignature);
    setShowSignatureSettings(true);
  };

  return (
    <>
      <div ref={tableRef} className={'h-full '}>
        {filteredSignatures.length === 0 ? (
          <div className="w-full h-full flex justify-center items-center select-none text-stone-400/80 text-sm">
            No signatures
          </div>
        ) : (
          <>
            {/* @ts-ignore */}
            <DataTable
              className={classes.Table}
              value={filteredSignatures}
              size="small"
              selectionMode={selectable ? 'single' : 'multiple'}
              selection={selectedSignatures}
              metaKeySelection
              onSelectionChange={handleSelectSignatures}
              dataKey="eve_id"
              tableClassName="w-full select-none"
              resizableColumns={false}
              onRowDoubleClick={handleRowClick}
              rowHover
              selectAll
              sortField={sortSettings.sortField}
              sortOrder={sortSettings.sortOrder}
              onSort={event => setSortSettings(() => ({ sortField: event.sortField, sortOrder: event.sortOrder }))}
              onRowMouseEnter={compact || medium ? handleEnterRow : undefined}
              onRowMouseLeave={compact || medium ? handleLeaveRow : undefined}
              rowClassName={row => {
                if (selectedSignatures.some(x => x.eve_id === row.eve_id)) {
                  return clsx(classes.TableRowCompact, 'bg-amber-500/50 hover:bg-amber-500/70 transition duration-200');
                }

                const dateClass = getRowColorByTimeLeft(row.inserted_at ? new Date(row.inserted_at) : undefined);
                if (!dateClass) {
                  return clsx(classes.TableRowCompact, 'hover:bg-purple-400/20 transition duration-200');
                }

                return clsx(classes.TableRowCompact, dateClass);
              }}
            >
              <Column
                bodyClassName="p-0 px-1"
                field="group"
                body={x => renderIcon(x)}
                style={{ maxWidth: 26, minWidth: 26, width: 26, height: 25 }}
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
                style={{ maxWidth: 110, minWidth: 110, width: 110 }}
                sortable
              ></Column>
              <Column
                field="info"
                bodyClassName="text-ellipsis overflow-hidden whitespace-nowrap"
                body={renderInfoColumn}
                style={{ maxWidth: nameColumnWidth }}
                hidden={compact || medium}
              ></Column>
              {showDescriptionColumn && (
                <Column
                  field="description"
                  header="Description"
                  bodyClassName="text-ellipsis overflow-hidden whitespace-nowrap"
                  body={renderDescription}
                  hidden={compact}
                  sortable
                ></Column>
              )}

              <Column
                field="inserted_at"
                header="Added"
                dataType="date"
                bodyClassName="w-[70px] text-ellipsis overflow-hidden whitespace-nowrap"
                body={renderAddedTimeLeft}
                sortable
              ></Column>

              {showUpdatedColumn && (
                <Column
                  field="updated_at"
                  header="Updated"
                  dataType="date"
                  bodyClassName="w-[70px] text-ellipsis overflow-hidden whitespace-nowrap"
                  body={renderUpdatedTimeLeft}
                  sortable
                ></Column>
              )}

              {!selectable && (
                <Column
                  bodyClassName="p-0 pl-1 pr-2"
                  field="group"
                  body={renderToolbar}
                  // headerClassName={headerClasses}
                  style={{ maxWidth: 26, minWidth: 26, width: 26 }}
                ></Column>
              )}
            </DataTable>
          </>
        )}
        <WdTooltip
          className="bg-stone-900/95 text-slate-50"
          ref={tooltipRef}
          content={hoveredSig ? <SignatureView {...hoveredSig} /> : null}
        />

        {showSignatureSettings && (
          <SignatureSettings
            systemId={systemId}
            show
            onHide={() => setShowSignatureSettings(false)}
            signatureData={selectedSignature}
          />
        )}
      </div>
    </>
  );
};
