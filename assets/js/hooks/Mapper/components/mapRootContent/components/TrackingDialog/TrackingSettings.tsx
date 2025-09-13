import { Dropdown } from 'primereact/dropdown';
import { useCallback, useMemo } from 'react';
import { TrackingCharacter } from '@/hooks/Mapper/types';
import { CharacterCard } from '@/hooks/Mapper/components/ui-kit';
import { useTracking } from '@/hooks/Mapper/components/mapRootContent/components/TrackingDialog/TrackingProvider.tsx';

const renderValCharacterTemplate = (row: TrackingCharacter | undefined) => {
  if (!row) {
    return <div className="h-[26px] flex items-center">Character is not selected</div>;
  }

  return (
    <div className="py-1 w-full">
      <CharacterCard compact isOwn {...row.character} />
    </div>
  );
};

const renderCharacterTemplate = (row: TrackingCharacter | undefined) => {
  if (!row) {
    return <div className="h-[33px] flex items-center">Character is not selected</div>;
  }

  return (
    <div className="w-full">
      <CharacterCard isOwn {...row.character} />
    </div>
  );
};

export const TrackingSettings = () => {
  const { trackingCharacters, following, main, updateFollowing, updateMain } = useTracking();

  const followingChar = useMemo(
    () => trackingCharacters.filter(x => x.tracked).find(x => x.character.eve_id === following),
    [following, trackingCharacters],
  );

  const availableForFollowingCharacters = useMemo(
    () => trackingCharacters.filter(x => x.tracked),
    [trackingCharacters],
  );

  const mainChar = useMemo(() => trackingCharacters.find(x => x.character.eve_id === main), [main, trackingCharacters]);

  const handleSelectFollowing = useCallback(
    (e: TrackingCharacter | null) => updateFollowing(e == null ? null : e.character.eve_id),
    [updateFollowing],
  );

  const handleSelectMain = useCallback((e: TrackingCharacter) => updateMain(e.character.eve_id), [updateMain]);

  return (
    <div className="w-full h-full flex flex-col gap-1">
      <div className="flex items-center justify-between gap-2 mx-2">
        <label className="text-stone-400 text-[13px] select-none">Main character</label>
        <Dropdown
          options={trackingCharacters}
          value={mainChar}
          onChange={e => handleSelectMain(e.value)}
          className="w-[230px]"
          itemTemplate={renderCharacterTemplate}
          valueTemplate={renderValCharacterTemplate}
        />
      </div>

      <div className="flex items-center justify-between gap-2 mx-2">
        <label className="text-stone-400 text-[13px] select-none">Following character</label>
        <Dropdown
          disabled={availableForFollowingCharacters.length === 0}
          options={availableForFollowingCharacters}
          value={followingChar}
          onChange={e => handleSelectFollowing(e.value)}
          className="w-[230px]"
          itemTemplate={renderCharacterTemplate}
          valueTemplate={renderValCharacterTemplate}
          showClear
          placeholder="Character is not selected"
        />
      </div>
    </div>
  );
};
