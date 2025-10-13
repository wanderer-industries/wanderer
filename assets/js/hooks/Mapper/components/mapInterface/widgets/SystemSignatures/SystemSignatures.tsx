import { Widget } from '@/hooks/Mapper/components/mapInterface/components';
import { SETTINGS_KEYS, SIGNATURE_WINDOW_ID, SignatureSettingsType } from '@/hooks/Mapper/constants/signatures';
import { useHotkey } from '@/hooks/Mapper/hooks/useHotkey';
import { useMapRootState } from '@/hooks/Mapper/mapRootProvider';
import { useCallback, useMemo, useState } from 'react';
import { useSignatureUndo } from './hooks/useSignatureUndo';
import { useSystemSignaturesData } from './hooks/useSystemSignaturesData';
import { SystemSignaturesHeader } from './SystemSignatureHeader';
import { SystemSignaturesContent } from './SystemSignaturesContent';
import { SystemSignatureSettingsDialog } from './SystemSignatureSettingsDialog';

export const SystemSignatures = () => {
  const [showSettings, setShowSettings] = useState(false);

  const {
    data: { selectedSystems },
    outCommand,
    storedSettings: { settingsSignatures, settingsSignaturesUpdate },
  } = useMapRootState();

  const [systemId] = selectedSystems;
  const isSystemSelected = useMemo(() => selectedSystems.length === 1, [selectedSystems.length]);

  const handleLazyDeleteToggle = useCallback(
    (value: boolean) => {
      settingsSignaturesUpdate(prev => ({
        ...prev,
        [SETTINGS_KEYS.LAZY_DELETE_SIGNATURES]: value,
      }));
    },
    [settingsSignaturesUpdate],
  );

  const {
    signatures,
    selectedSignatures,
    setSelectedSignatures,
    handleDeleteSelected,
    handleSelectAll,
    handlePaste,
    hasUnsupportedLanguage,
  } = useSystemSignaturesData({
    systemId,
    settings: settingsSignatures,
    onLazyDeleteChange: handleLazyDeleteToggle,
  });

  const sigCount = useMemo(() => signatures.length, [signatures]);
  const deletedSignatures = useMemo(() => signatures.filter(s => s.deleted), [signatures]);

  const { countdown, handleUndo } = useSignatureUndo(systemId, settingsSignatures, deletedSignatures, outCommand);

  useHotkey(true, ['z', 'Z'], (event: KeyboardEvent) => {
    if (deletedSignatures.length > 0 && countdown > 0) {
      event.preventDefault();
      event.stopPropagation();
      handleUndo();
    }
  });

  const handleSettingsSave = useCallback(
    (newSettings: SignatureSettingsType) => {
      settingsSignaturesUpdate(newSettings);
      setShowSettings(false);
    },
    [settingsSignaturesUpdate],
  );

  const openSettings = useCallback(() => setShowSettings(true), []);

  return (
    <Widget
      label={
        <SystemSignaturesHeader
          sigCount={sigCount}
          lazyDeleteValue={settingsSignatures[SETTINGS_KEYS.LAZY_DELETE_SIGNATURES] as boolean}
          pendingCount={deletedSignatures.length}
          undoCountdown={countdown}
          onLazyDeleteChange={handleLazyDeleteToggle}
          onUndoClick={handleUndo}
          onSettingsClick={openSettings}
        />
      }
      windowId={SIGNATURE_WINDOW_ID}
    >
      {!isSystemSelected ? (
        <div className="w-full h-full flex justify-center items-center select-none text-center text-stone-400/80 text-sm">
          System is not selected
        </div>
      ) : (
        <SystemSignaturesContent
          systemId={systemId}
          signatures={signatures}
          selectedSignatures={selectedSignatures}
          onSelectSignatures={setSelectedSignatures}
          onDeleteSelected={handleDeleteSelected}
          onSelectAll={handleSelectAll}
          onPaste={handlePaste}
          hasUnsupportedLanguage={hasUnsupportedLanguage}
          settings={settingsSignatures}
        />
      )}

      {showSettings && (
        <SystemSignatureSettingsDialog
          settings={settingsSignatures}
          onCancel={() => setShowSettings(false)}
          onSave={handleSettingsSave}
        />
      )}
    </Widget>
  );
};

export default SystemSignatures;
