import { useMapRootState } from '@/hooks/Mapper/mapRootProvider';
import { useMapSettings } from '@/hooks/Mapper/components/mapRootContent/components/MapSettings/MapSettingsProvider.tsx';
import { BOOKMARKS_SETTINGS_PROPS } from '../constants.ts';
import { BookmarkNameFormatSetting } from './BookmarkNameFormatSetting';

export const BookmarksSettings = () => {
  const {
    storedSettings: { interfaceSettings, setInterfaceSettings },
  } = useMapRootState();
  const { renderSettingItem, settings } = useMapSettings();

  return (
    <div className="w-full h-full flex flex-col gap-3 overflow-y-auto custom-scrollbar pr-1">
      {!settings.link_signature_on_splash && !interfaceSettings.hideBookmarkWarning && (
        <div className="relative p-2 pr-6 bg-yellow-900/30 border border-yellow-700/50 rounded text-yellow-500/90 text-sm">
          ⚠️ It is highly recommended to enable 'Link signature on splash' (in the Signatures tab) to fully utilize
          automatic bookmark naming.
          <button
            type="button"
            className="absolute top-1 right-2 text-yellow-700 hover:text-yellow-500 transition-colors"
            onClick={() => setInterfaceSettings(prev => ({ ...prev, hideBookmarkWarning: true }))}
          >
            <i className="pi pi-times text-xs"></i>
          </button>
        </div>
      )}

      <div className="flex flex-col gap-1 mt-2">{BOOKMARKS_SETTINGS_PROPS.map(renderSettingItem)}</div>

      <BookmarkNameFormatSetting />
    </div>
  );
};
