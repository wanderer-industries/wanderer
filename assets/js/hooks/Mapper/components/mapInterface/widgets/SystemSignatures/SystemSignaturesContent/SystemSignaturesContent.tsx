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
  renderLinkedSystem,
} from '@/hooks/Mapper/components/mapInterface/widgets/SystemSignatures/renders';
// import { PrimeIcons } from 'primereact/api';
import useLocalStorageState from 'use-local-storage-state';

type SystemSignaturesSortSettings = {
  sortField: string;
  sortOrder: SortOrder;
};

const SORT_DEFAULT_VALUES: SystemSignaturesSortSettings = {
  sortField: 'updated_at',
  sortOrder: -1,
};

interface SystemSignaturesContentProps {
  systemId: string;
  settings: Setting[];
  selectable?: boolean;
  onSelect?: (signatures: SystemSignature[]) => void;
}
export const SystemSignaturesContent = ({ systemId, settings, selectable, onSelect }: SystemSignaturesContentProps) => {
  const { outCommand } = useMapRootState();

  const [signatures, setSignatures, signaturesRef] = useRefState<SystemSignature[]>([]);
  const [selectedSignatures, setSelectedSignatures] = useState<SystemSignature[]>([]);
  const [nameColumnWidth, setNameColumnWidth] = useState('auto');
  const [parsedSignatures, setParsedSignatures] = useState<SystemSignature[]>([]);
  const [askUser, setAskUser] = useState(false);

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
      const otherColumnsWidth = 276;
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

    setAskUser(false);
    setSignatures(signatures);
  }, [outCommand, systemId]);

  // const updateSignatures = useCallback(
  //   async (newSignatures: SystemSignature[], updateOnly: boolean) => {
  //     const { added, updated, removed } = getActualSigs(signaturesRef.current, newSignatures, updateOnly);

  //     const { signatures: updatedSignatures } = await outCommand({
  //       type: OutCommand.updateSignatures,
  //       data: {
  //         system_id: systemId,
  //         added,
  //         updated,
  //         removed,
  //       },
  //     });

  //     setSignatures(() => updatedSignatures);
  //     setSelectedSignatures([]);
  //   },
  //   [outCommand, systemId],
  // );

  const handleUpdateSignatures = useCallback(
    async (newSignatures: SystemSignature[], updateOnly: boolean) => {
      const { added, updated, removed } = getActualSigs(signaturesRef.current, newSignatures, updateOnly);

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
    if (selectable) {
      return;
    }
    if (selectedSignatures.length === 0) {
      return;
    }
    const selectedSignaturesEveIds = selectedSignatures.map(x => x.eve_id);
    await handleUpdateSignatures(
      signatures.filter(x => !selectedSignaturesEveIds.includes(x.eve_id)),
      false,
    );
  }, [handleUpdateSignatures, selectable, signatures, selectedSignatures]);

  const handleSelectAll = useCallback(() => {
    setSelectedSignatures(signatures);
  }, [signatures]);

  const handleReplaceAll = useCallback(() => {
    handleUpdateSignatures(parsedSignatures, false);
    setAskUser(false);
  }, [parsedSignatures, handleUpdateSignatures]);

  const handleUpdateOnly = useCallback(() => {
    handleUpdateSignatures(parsedSignatures, true);
    setAskUser(false);
  }, [parsedSignatures, handleUpdateSignatures]);

  const handleSelectSignatures = useCallback(
    e => {
      if (selectable) {
        onSelect?.(e.value);
      } else {
        setSelectedSignatures(e.value);
      }
    },
    [onSelect, selectable],
  );

  useHotkey(true, ['a'], handleSelectAll);

  useHotkey(false, ['Backspace', 'Delete'], handleDeleteSelected);

  useEffect(() => {
    if (selectable) {
      return;
    }

    if (!clipboardContent) {
      return;
    }

    const newSignatures = parseSignatures(
      clipboardContent,
      settings.map(x => x.key),
    );

    const { removed } = getActualSigs(signaturesRef.current, newSignatures, false);

    if (!signaturesRef.current || !signaturesRef.current.length || !removed.length) {
      handleUpdateSignatures(newSignatures, false);
    } else {
      setParsedSignatures(newSignatures);
      setAskUser(true);
    }
  }, [clipboardContent, selectable]);

  useEffect(() => {
    if (!systemId) {
      setSignatures([]);
      setAskUser(false);
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

  // const renderToolbar = (/*row: SystemSignature*/) => {
  //   return (
  //     <div className="flex justify-end items-center gap-2">
  //       <span className={clsx(PrimeIcons.PENCIL, 'text-[10px]')}></span>
  //     </div>
  //   );
  // };

  return (
    <>
      <div ref={tableRef} className={'h-full '}>
        {filteredSignatures.length === 0 ? (
          <div className="w-full h-full flex justify-center items-center select-none text-stone-400/80 text-sm">
            No signatures
          </div>
        ) : (
          <>
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
                field="linked_system"
                header="Linked System"
                bodyClassName="text-ellipsis overflow-hidden whitespace-nowrap"
                body={renderLinkedSystem}
                style={{ maxWidth: nameColumnWidth }}
                hidden={compact}
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

              {/*<Column*/}
              {/*  bodyClassName="p-0 pl-1 pr-2"*/}
              {/*  field="group"*/}
              {/*  body={renderToolbar}*/}
              {/*  headerClassName={headerClasses}*/}
              {/*  style={{ maxWidth: 26, minWidth: 26, width: 26 }}*/}
              {/*></Column>*/}
            </DataTable>
          </>
        )}
        <WdTooltip
          className="bg-stone-900/95 text-slate-50"
          ref={tooltipRef}
          content={hoveredSig ? <SignatureView {...hoveredSig} /> : null}
        />
        {askUser && (
          <div className="absolute left-[1px] top-[29px] h-[calc(100%-30px)] w-[calc(100%-3px)] bg-stone-900/10 backdrop-blur-sm">
            <div className="absolute top-0 left-0 w-full h-full flex flex-col items-center justify-center">
              <div className="text-stone-400/80 text-sm">
                <div className="flex flex-col text-center gap-2">
                  <button className="p-button p-component p-button-outlined p-button-sm btn-wide">
                    <span className="p-button-label p-c" onClick={handleUpdateOnly}>
                      Update
                    </span>
                  </button>
                  <button className="p-button p-component p-button-outlined p-button-sm btn-wide">
                    <span className="p-button-label p-c" onClick={handleReplaceAll}>
                      Update & Delete
                    </span>
                  </button>
                </div>
              </div>
            </div>
          </div>
        )}
      </div>
    </>
  );
};
