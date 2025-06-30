import React, { useCallback } from 'react';
import { TrackingCharacter } from '@/hooks/Mapper/types';

interface ReadyCharactersListProps {
  trackingCharacters: TrackingCharacter[];
  ready: string[];
  onReadyChange: (characterId: string, isReady: boolean) => void;
}

export const ReadyCharactersList = ({ trackingCharacters, ready, onReadyChange }: ReadyCharactersListProps) => {
  const offlineCount = trackingCharacters.filter(({ character }) => !character.online).length;
  const availableCharacters = trackingCharacters.filter(({ character }) => character.online);

  const handleCheckboxChange = useCallback(
    (id: string, checked: boolean) => onReadyChange(id, checked),
    [onReadyChange],
  );

  return (
    <div className="h-full flex flex-col">
      {availableCharacters.length === 0 ? (
        <div className="text-center text-stone-400 py-4">
          {offlineCount > 0 ? (
            <>
              <p>No online characters to select.</p>
              <p className="text-xs mt-1">
                {offlineCount} offline character{offlineCount !== 1 ? 's' : ''} hidden
              </p>
            </>
          ) : (
            <p>No characters available.</p>
          )}
        </div>
      ) : (
        <div className="space-y-1">
          {availableCharacters.map(({ character }) => {
            const { eve_id, name, ship } = character;
            const isReady = ready.includes(eve_id);
            const shipTypeName = ship?.ship_type_info?.name;
            const shipName = ship?.ship_name;
            const shipInfo = shipTypeName ? `${shipTypeName} (${shipName})` : shipName || 'Unknown ship';

            return (
              <label
                key={eve_id}
                className={`
                  flex items-center justify-between p-2 rounded cursor-pointer transition-colors text-sm border
                  ${
                    isReady
                      ? 'bg-[var(--surface-hover)] border-[var(--surface-border)]'
                      : 'bg-[var(--surface-card)] border-[var(--surface-border)] hover:bg-[var(--surface-hover)]'
                  }
                `}
              >
                <div className="flex items-center space-x-3 flex-1">
                  <input
                    type="checkbox"
                    checked={isReady}
                    onChange={e => handleCheckboxChange(eve_id, e.target.checked)}
                    className="w-4 h-4 rounded bg-[var(--surface-card)] border-[var(--surface-border)]"
                    style={{ accentColor: 'var(--primary-color)' }}
                  />
                  <div className="flex items-center space-x-2 flex-1">
                    <span className="text-sm" style={{ color: 'var(--orange-400)' }}>
                      {name}
                    </span>
                    <span className="text-xs" style={{ color: 'var(--gray-500)' }}>
                      •
                    </span>
                    <span className="text-xs text-stone-400">{shipInfo}</span>
                  </div>
                </div>
                <div className="text-xs" style={{ color: 'var(--primary-color)' }}>
                  Online
                </div>
              </label>
            );
          })}
        </div>
      )}
    </div>
  );
};
