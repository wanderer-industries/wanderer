import { useEffect, useMemo, useRef, useState, useCallback } from 'react';
import { DataTable, DataTableRowClickEvent, DataTableRowMouseEvent, SortOrder } from 'primereact/datatable';
import { Column } from 'primereact/column';
import { PrimeIcons } from 'primereact/api';
import useLocalStorageState from 'use-local-storage-state';

import { SignatureGroup, SystemSignature } from '@/hooks/Mapper/types';
import { SignatureSettings } from '@/hooks/Mapper/components/mapRootContent/components/SignatureSettings';
import { WdTooltip, WdTooltipHandlers, WdTooltipWrapper } from '@/hooks/Mapper/components/ui-kit';
import { SignatureView } from '@/hooks/Mapper/components/mapInterface/widgets/SystemSignatures/SignatureView';
import {
  COMPACT_MAX_WIDTH,
  GROUPS_LIST,
  MEDIUM_MAX_WIDTH,
  OTHER_COLUMNS_WIDTH,
  getGroupIdByRawGroup,
} from '@/hooks/Mapper/components/mapInterface/widgets/SystemSignatures/constants';
import {
  SHOW_DESCRIPTION_COLUMN_SETTING,
  SHOW_UPDATED_COLUMN_SETTING,
  SHOW_CHARACTER_COLUMN_SETTING,
  SIGNATURE_WINDOW_ID,
} from '../SystemSignatures';

import { COSMIC_SIGNATURE } from '../SystemSignatureSettingsDialog';
import {
  renderAddedTimeLeft,
  renderDescription,
  renderIcon,
  renderInfoColumn,
  renderUpdatedTimeLeft,
} from '@/hooks/Mapper/components/mapInterface/widgets/SystemSignatures/renders';
import { ExtendedSystemSignature } from '../helpers/contentHelpers';
import { useSystemSignaturesData } from '../hooks/useSystemSignaturesData';
import { getSignatureRowClass } from '../helpers/rowStyles';
import useMaxWidth from '@/hooks/Mapper/hooks/useMaxWidth';
import { useClipboard, useHotkey } from '@/hooks/Mapper/hooks';

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
  settings: { key: string; value: boolean | number }[];
  hideLinkedSignatures?: boolean;
  selectable?: boolean;
  onSelect?: (signature: SystemSignature) => void;
  onLazyDeleteChange?: (value: boolean) => void;
  onCountChange?: (count: number) => void;
  onPendingChange?: (pending: ExtendedSystemSignature[], undo: () => void) => void;
  deletionTiming?: number;
  colorByType?: boolean;
}

const headerInlineStyle = { padding: '2px', fontSize: '12px', lineHeight: '1.333' };

export function SystemSignaturesContent({
  systemId,
  settings,
  hideLinkedSignatures,
  selectable,
  onSelect,
  onLazyDeleteChange,
  onCountChange,
  onPendingChange,
  deletionTiming,
  colorByType,
}: SystemSignaturesContentProps) {
  const { signatures, selectedSignatures, setSelectedSignatures, handleDeleteSelected, handleSelectAll, handlePaste } =
    useSystemSignaturesData({
      systemId,
      settings,
      onCountChange,
      onPendingChange,
      onLazyDeleteChange,
      deletionTiming,
    });

  const [sortSettings, setSortSettings] = useLocalStorageState<{ sortField: string; sortOrder: SortOrder }>(
    'window:signatures:sort',
    { defaultValue: SORT_DEFAULT_VALUES },
  );

  const tableRef = useRef<HTMLDivElement>(null);
  const tooltipRef = useRef<WdTooltipHandlers>(null);
  const [hoveredSignature, setHoveredSignature] = useState<SystemSignature | null>(null);

  const isCompact = useMaxWidth(tableRef, COMPACT_MAX_WIDTH);
  const isMedium = useMaxWidth(tableRef, MEDIUM_MAX_WIDTH);

  const { clipboardContent, setClipboardContent } = useClipboard();
  useEffect(() => {
    if (selectable) return;
    if (!clipboardContent?.text) return;

    handlePaste(clipboardContent.text);

    setClipboardContent(null);
  }, [selectable, clipboardContent, handlePaste, setClipboardContent]);

  useHotkey(true, ['a'], handleSelectAll);
  useHotkey(false, ['Backspace', 'Delete'], (event: KeyboardEvent) => {
    const targetWindow = (event.target as HTMLHtmlElement)?.closest(`[data-window-id="${SIGNATURE_WINDOW_ID}"]`);

    if (!targetWindow) {
      return;
    }

    event.preventDefault();
    event.stopPropagation();
    handleDeleteSelected();
  });

  const [nameColumnWidth, setNameColumnWidth] = useState('auto');
  const handleResize = useCallback(() => {
    if (!tableRef.current) return;
    const tableWidth = tableRef.current.offsetWidth;
    const otherColumnsWidth = OTHER_COLUMNS_WIDTH;
    setNameColumnWidth(`${tableWidth - otherColumnsWidth}px`);
  }, []);
  useEffect(() => {
    if (!tableRef.current) return;
    const observer = new ResizeObserver(handleResize);
    observer.observe(tableRef.current);
    handleResize();
    return () => {
      observer.disconnect();
    };
  }, [handleResize]);

  const [selectedSignatureForDialog, setSelectedSignatureForDialog] = useState<SystemSignature | null>(null);
  const [showSignatureSettings, setShowSignatureSettings] = useState(false);

  const handleRowClick = (e: DataTableRowClickEvent) => {
    setSelectedSignatureForDialog(e.data as SystemSignature);
    setShowSignatureSettings(true);
  };

  const handleSelectSignatures = useCallback(
    (e: { value: SystemSignature[] }) => {
      if (selectable) {
        onSelect?.(e.value[0]);
      } else {
        setSelectedSignatures(e.value as ExtendedSystemSignature[]);
      }
    },
    [selectable, onSelect, setSelectedSignatures],
  );

  const showDescriptionColumn = settings.find(s => s.key === SHOW_DESCRIPTION_COLUMN_SETTING)?.value;
  const showUpdatedColumn = settings.find(s => s.key === SHOW_UPDATED_COLUMN_SETTING)?.value;
  const showCharacterColumn = settings.find(s => s.key === SHOW_CHARACTER_COLUMN_SETTING)?.value;

  const enabledGroups = settings
    .filter(s => GROUPS_LIST.includes(s.key as SignatureGroup) && s.value === true)
    .map(s => s.key);

  const filteredSignatures = useMemo<ExtendedSystemSignature[]>(() => {
    return signatures.filter(sig => {
      if (hideLinkedSignatures && sig.linked_system) {
        return false;
      }
      const isCosmicSignature = sig.kind === COSMIC_SIGNATURE;

      if (isCosmicSignature) {
        const showCosmic = settings.find(y => y.key === COSMIC_SIGNATURE)?.value;
        if (!showCosmic) return false;
        if (sig.group) {
          const preparedGroup = getGroupIdByRawGroup(sig.group);
          return enabledGroups.includes(preparedGroup);
        }
        return true;
      } else {
        return settings.find(y => y.key === sig.kind)?.value;
      }
    });
  }, [signatures, hideLinkedSignatures, settings, enabledGroups]);

  return (
    <div ref={tableRef} className="h-full">
      {filteredSignatures.length === 0 ? (
        <div className="w-full h-full flex justify-center items-center select-none text-stone-400/80 text-sm">
          No signatures
        </div>
      ) : (
        <DataTable
          value={filteredSignatures}
          size="small"
          selectionMode="multiple"
          selection={selectedSignatures}
          metaKeySelection
          onSelectionChange={handleSelectSignatures}
          dataKey="eve_id"
          className="w-full select-none"
          resizableColumns={false}
          rowHover
          selectAll
          onRowDoubleClick={handleRowClick}
          sortField={sortSettings.sortField}
          sortOrder={sortSettings.sortOrder}
          onSort={e => setSortSettings({ sortField: e.sortField, sortOrder: e.sortOrder })}
          onRowMouseEnter={
            isCompact || isMedium
              ? (e: DataTableRowMouseEvent) => {
                  setHoveredSignature(filteredSignatures[e.index]);
                  tooltipRef.current?.show(e.originalEvent);
                }
              : undefined
          }
          onRowMouseLeave={
            isCompact || isMedium
              ? () => {
                  setHoveredSignature(null);
                  tooltipRef.current?.hide();
                }
              : undefined
          }
          rowClassName={rowData =>
            getSignatureRowClass(rowData as ExtendedSystemSignature, selectedSignatures, colorByType)
          }
        >
          <Column
            field="icon"
            header=""
            headerStyle={headerInlineStyle}
            body={sig => renderIcon(sig)}
            bodyClassName="p-0 px-1"
            style={{ maxWidth: 26, minWidth: 26, width: 26 }}
          />
          <Column
            field="eve_id"
            header="Id"
            headerStyle={headerInlineStyle}
            bodyClassName="text-ellipsis overflow-hidden whitespace-nowrap"
            style={{ maxWidth: 72, minWidth: 72, width: 72 }}
            sortable
          />
          <Column
            field="group"
            header="Group"
            headerStyle={headerInlineStyle}
            bodyClassName="text-ellipsis overflow-hidden whitespace-nowrap"
            style={{ maxWidth: 110, minWidth: 110, width: 110 }}
            body={sig => sig.group ?? ''}
            hidden={isCompact}
            sortable
          />
          <Column
            field="info"
            header="Info"
            headerStyle={headerInlineStyle}
            bodyClassName="text-ellipsis overflow-hidden whitespace-nowrap"
            style={{ maxWidth: nameColumnWidth }}
            hidden={isCompact || isMedium}
            body={renderInfoColumn}
          />
          {showDescriptionColumn && (
            <Column
              field="description"
              header="Description"
              headerStyle={headerInlineStyle}
              bodyClassName="text-ellipsis overflow-hidden whitespace-nowrap"
              hidden={isCompact}
              body={renderDescription}
              sortable
            />
          )}
          <Column
            field="inserted_at"
            header="Added"
            headerStyle={headerInlineStyle}
            dataType="date"
            body={renderAddedTimeLeft}
            style={{ minWidth: 70, maxWidth: 80 }}
            bodyClassName="text-ellipsis overflow-hidden whitespace-nowrap"
            sortable
          />
          {showUpdatedColumn && (
            <Column
              field="updated_at"
              header="Updated"
              headerStyle={headerInlineStyle}
              dataType="date"
              body={renderUpdatedTimeLeft}
              style={{ minWidth: 70, maxWidth: 80 }}
              bodyClassName="text-ellipsis overflow-hidden whitespace-nowrap"
              sortable
            />
          )}

          {showCharacterColumn && (
            <Column
              field="character_name"
              header="Character"
              bodyClassName="w-[70px] text-ellipsis overflow-hidden whitespace-nowrap"
              sortable
            ></Column>
          )}

          {!selectable && (
            <Column
              header=""
              headerStyle={headerInlineStyle}
              body={() => (
                <div className="flex justify-end items-center gap-2 mr-[4px]">
                  <WdTooltipWrapper content="Double-click a row to edit signature">
                    <span className={PrimeIcons.PENCIL + ' text-[10px]'} />
                  </WdTooltipWrapper>
                </div>
              )}
              style={{ maxWidth: 26, minWidth: 26, width: 26 }}
              bodyClassName="p-0 pl-1 pr-2"
            />
          )}
        </DataTable>
      )}

      <WdTooltip
        className="bg-stone-900/95 text-slate-50"
        ref={tooltipRef}
        content={hoveredSignature ? <SignatureView {...hoveredSignature} /> : null}
      />

      {showSignatureSettings && (
        <SignatureSettings
          systemId={systemId}
          show
          onHide={() => setShowSignatureSettings(false)}
          signatureData={selectedSignatureForDialog || undefined}
        />
      )}
    </div>
  );
}
