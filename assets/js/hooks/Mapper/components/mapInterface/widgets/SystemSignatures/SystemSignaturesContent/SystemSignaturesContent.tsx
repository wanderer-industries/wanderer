import { PrimeIcons } from 'primereact/api';
import { Column } from 'primereact/column';
import {
  DataTable,
  DataTableRowClickEvent,
  DataTableRowMouseEvent,
  DataTableStateEvent,
  SortOrder,
} from 'primereact/datatable';
import { useCallback, useEffect, useMemo, useRef, useState } from 'react';

import { SignatureView } from '@/hooks/Mapper/components/mapInterface/widgets/SystemSignatures/SignatureView';
import {
  COMPACT_MAX_WIDTH,
  getGroupIdByRawGroup,
  GROUPS_LIST,
  MEDIUM_MAX_WIDTH,
  OTHER_COLUMNS_WIDTH,
} from '@/hooks/Mapper/components/mapInterface/widgets/SystemSignatures/constants';
import { SignatureSettings } from '@/hooks/Mapper/components/mapRootContent/components/SignatureSettings';
import { TooltipPosition, WdTooltip, WdTooltipHandlers, WdTooltipWrapper } from '@/hooks/Mapper/components/ui-kit';
import { ExtendedSystemSignature, SignatureGroup, SignatureKind, SystemSignature } from '@/hooks/Mapper/types';

import {
  renderAddedTimeLeft,
  renderDescription,
  renderIcon,
  renderInfoColumn,
  renderUpdatedTimeLeft,
} from '@/hooks/Mapper/components/mapInterface/widgets/SystemSignatures/renders';
import { SETTINGS_KEYS, SIGNATURE_WINDOW_ID, SignatureSettingsType } from '@/hooks/Mapper/constants/signatures.ts';
import { useClipboard, useHotkey } from '@/hooks/Mapper/hooks';
import useMaxWidth from '@/hooks/Mapper/hooks/useMaxWidth';
import { useMapRootState } from '@/hooks/Mapper/mapRootProvider';
import { getSignatureRowClass } from '../helpers/rowStyles';

const renderColIcon = (sig: SystemSignature) => renderIcon(sig);

interface SystemSignaturesContentProps {
  systemId: string;
  signatures: ExtendedSystemSignature[];
  selectedSignatures?: ExtendedSystemSignature[];
  onSelectSignatures?: (s: ExtendedSystemSignature[]) => void;
  onDeleteSelected?: () => Promise<void>;
  onSelectAll?: () => void;
  onPaste?: (clipboardString: string) => void;
  settings: SignatureSettingsType;
  hideLinkedSignatures?: boolean;
  hasUnsupportedLanguage?: boolean;
  selectable?: boolean;
  onSelect?: (signature: SystemSignature) => void;
  filterSignature?: (signature: SystemSignature) => boolean;
}

export const SystemSignaturesContent = ({
  systemId,
  signatures,
  selectedSignatures,
  onSelectSignatures,
  onDeleteSelected,
  onSelectAll,
  onPaste,
  settings,
  hideLinkedSignatures,
  hasUnsupportedLanguage,
  selectable,
  onSelect,
  filterSignature,
}: SystemSignaturesContentProps) => {
  const [selectedSignatureForDialog, setSelectedSignatureForDialog] = useState<SystemSignature | null>(null);
  const [showSignatureSettings, setShowSignatureSettings] = useState(false);
  const [nameColumnWidth, setNameColumnWidth] = useState('auto');
  const [hoveredSignature, setHoveredSignature] = useState<SystemSignature | null>(null);

  const {
    storedSettings: { settingsSignatures, settingsSignaturesUpdate },
  } = useMapRootState();

  const tableRef = useRef<HTMLDivElement>(null);
  const tooltipRef = useRef<WdTooltipHandlers>(null);

  const isCompact = useMaxWidth(tableRef, COMPACT_MAX_WIDTH);
  const isMedium = useMaxWidth(tableRef, MEDIUM_MAX_WIDTH);

  const { clipboardContent, setClipboardContent } = useClipboard();

  const deletedSignatures = useMemo(() => signatures.filter(s => s.deleted), [signatures]);

  useEffect(() => {
    if (selectable) return;
    if (!clipboardContent?.text) return;

    onPaste?.(clipboardContent.text);

    setClipboardContent(null);
  }, [selectable, clipboardContent, onPaste, setClipboardContent]);

  useHotkey(true, ['a'], () => onSelectAll?.());

  useHotkey(false, ['Backspace', 'Delete'], (event: KeyboardEvent) => {
    const targetWindow = (event.target as HTMLHtmlElement)?.closest(`[data-window-id="${SIGNATURE_WINDOW_ID}"]`);

    if (!targetWindow) {
      return;
    }

    event.preventDefault();
    event.stopPropagation();

    // Delete key should always immediately delete, never show pending deletions
    onDeleteSelected?.();
  });

  const handleResize = useCallback(() => {
    if (!tableRef.current) return;

    setNameColumnWidth(`${tableRef.current.offsetWidth - OTHER_COLUMNS_WIDTH}px`);
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

  const handleRowClick = useCallback((e: DataTableRowClickEvent) => {
    setSelectedSignatureForDialog(e.data as SystemSignature);
    setShowSignatureSettings(true);
  }, []);

  const handleSelectSignatures = useCallback(
    (e: { value: SystemSignature[] }) => {
      // Filter out deleted signatures from selection
      const selectableSignatures = e.value.filter(
        sig => !deletedSignatures.some(deleted => deleted.eve_id === sig.eve_id),
      );

      selectable
        ? onSelect?.(selectableSignatures[0])
        : onSelectSignatures?.(selectableSignatures as ExtendedSystemSignature[]);
    },
    [onSelect, selectable, onSelectSignatures, deletedSignatures],
  );

  const {
    showGroupColumn,
    showDescriptionColumn,
    showAddedColumn,
    showUpdatedColumn,
    showCharacterColumn,
    showCharacterPortrait,
  } = useMemo(
    () => ({
      showGroupColumn: settings[SETTINGS_KEYS.SHOW_GROUP_COLUMN] as boolean,
      showDescriptionColumn: settings[SETTINGS_KEYS.SHOW_DESCRIPTION_COLUMN] as boolean,
      showAddedColumn: settings[SETTINGS_KEYS.SHOW_ADDED_COLUMN] as boolean,
      showUpdatedColumn: settings[SETTINGS_KEYS.SHOW_UPDATED_COLUMN] as boolean,
      showCharacterColumn: settings[SETTINGS_KEYS.SHOW_CHARACTER_COLUMN] as boolean,
      showCharacterPortrait: settings[SETTINGS_KEYS.SHOW_CHARACTER_PORTRAIT] as boolean,
    }),
    [settings],
  );

  const filteredSignatures = useMemo<ExtendedSystemSignature[]>(() => {
    // Common filter function
    const shouldShowSignature = (sig: ExtendedSystemSignature): boolean => {
      if (filterSignature && !filterSignature(sig)) {
        return false;
      }

      if (hideLinkedSignatures && sig.linked_system) {
        return false;
      }

      if (sig.kind === SignatureKind.CosmicSignature) {
        if (!settings[SETTINGS_KEYS.COSMIC_SIGNATURE]) {
          return false;
        }

        if (sig.group) {
          const enabledGroups = Object.keys(settings).filter(
            x => GROUPS_LIST.includes(x as SignatureGroup) && settings[x as SETTINGS_KEYS],
          );

          const mappedGroup = getGroupIdByRawGroup(sig.group);
          if (!mappedGroup) {
            return true; // If we can't determine the group, still show it
          }
          return enabledGroups.includes(mappedGroup);
        }

        return true;
      }

      return settings[sig.kind] as boolean;
    };

    return signatures.filter(sig => shouldShowSignature(sig));
  }, [signatures, hideLinkedSignatures, settings, filterSignature]);

  const onRowMouseEnter = useCallback((e: DataTableRowMouseEvent) => {
    setHoveredSignature(e.data as SystemSignature);
    tooltipRef.current?.show(e.originalEvent);
  }, []);

  const onRowMouseLeave = useCallback(() => {
    setHoveredSignature(null);
    tooltipRef.current?.hide();
  }, []);

  const refVars = useRef({ settings, selectedSignatures, settingsSignatures, settingsSignaturesUpdate });
  refVars.current = { settings, selectedSignatures, settingsSignatures, settingsSignaturesUpdate };

  // @ts-ignore
  const getRowClassName = useCallback(rowData => {
    if (!rowData) {
      return null;
    }

    return getSignatureRowClass(
      rowData as ExtendedSystemSignature,
      refVars.current.selectedSignatures || [],
      refVars.current.settings[SETTINGS_KEYS.COLOR_BY_TYPE] as boolean,
    );
  }, []);

  const handleSortSettings = useCallback((e: DataTableStateEvent) => {
    refVars.current.settingsSignaturesUpdate({
      ...refVars.current.settingsSignatures,
      [SETTINGS_KEYS.SORT_FIELD]: e.sortField,
      [SETTINGS_KEYS.SORT_ORDER]: e.sortOrder,
    });
  }, []);

  return (
    <div ref={tableRef} className="h-full">
      {filteredSignatures.length === 0 ? (
        <div className="w-full h-full flex justify-center items-center select-none text-stone-400/80 text-sm">
          No signatures
        </div>
      ) : (
        <>
          {hasUnsupportedLanguage && (
            <div className="w-full flex justify-center items-center text-amber-500 text-xs p-1 bg-amber-950/20 border-b border-amber-800/30">
              <i className={PrimeIcons.EXCLAMATION_TRIANGLE + ' mr-1'} />
              Non-English signatures detected. Some signatures may not display correctly. Double-click to edit signature
              details.
            </div>
          )}
          <DataTable
            value={filteredSignatures}
            size="small"
            selectionMode="multiple"
            selection={selectedSignatures || []}
            metaKeySelection
            onSelectionChange={handleSelectSignatures}
            dataKey="eve_id"
            className="w-full select-none"
            resizableColumns={false}
            rowHover
            selectAll
            onRowDoubleClick={handleRowClick}
            sortField={settingsSignatures[SETTINGS_KEYS.SORT_FIELD] as string}
            sortOrder={settingsSignatures[SETTINGS_KEYS.SORT_ORDER] as SortOrder}
            onSort={handleSortSettings}
            onRowMouseEnter={onRowMouseEnter}
            onRowMouseLeave={onRowMouseLeave}
            // @ts-ignore
            rowClassName={getRowClassName}
          >
            <Column
              field="icon"
              header=""
              body={renderColIcon}
              bodyClassName="p-0 px-1"
              style={{ maxWidth: 26, minWidth: 26, width: 26 }}
            />
            <Column
              field="eve_id"
              header="Id"
              bodyClassName="text-ellipsis overflow-hidden whitespace-nowrap"
              style={{ maxWidth: 72, minWidth: 72, width: 72 }}
              sortable
            />
            {showGroupColumn && (
              <Column
                field="group"
                header="Group"
                bodyClassName="text-ellipsis overflow-hidden whitespace-nowrap"
                style={{ maxWidth: 110, minWidth: 110, width: 110 }}
                body={sig => sig.group ?? ''}
                hidden={isCompact}
                sortable
              />
            )}
            <Column
              field="info"
              header="Info"
              bodyClassName="text-ellipsis overflow-hidden whitespace-nowrap"
              style={{ maxWidth: nameColumnWidth }}
              hidden={isCompact || isMedium}
              body={renderInfoColumn}
              sortable
              sortField="name"
            />
            {showDescriptionColumn && (
              <Column
                field="description"
                header="Description"
                bodyClassName="text-ellipsis overflow-hidden whitespace-nowrap"
                hidden={isCompact}
                body={renderDescription}
                sortable
              />
            )}
            {showAddedColumn && (
              <Column
                field="inserted_at"
                header="Added"
                dataType="date"
                body={renderAddedTimeLeft}
                style={{ minWidth: 70, maxWidth: 80 }}
                bodyClassName="ssc-header text-ellipsis overflow-hidden whitespace-nowrap"
                sortable
              />
            )}
            {showUpdatedColumn && (
              <Column
                field="updated_at"
                header="Updated"
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
        </>
      )}

      <WdTooltip
        className="bg-stone-900/95 text-slate-50"
        ref={tooltipRef}
        position={TooltipPosition.top}
        content={
          hoveredSignature ? (
            <SignatureView signature={hoveredSignature} showCharacterPortrait={showCharacterPortrait} />
          ) : null
        }
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
};
