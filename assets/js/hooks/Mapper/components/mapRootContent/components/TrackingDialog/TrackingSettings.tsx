import { Dropdown } from 'primereact/dropdown';
import { useMapRootState } from '@/hooks/Mapper/mapRootProvider';
import { useCallback, useEffect, useMemo, useState } from 'react';
import { OutCommand, TrackingCharacter } from '@/hooks/Mapper/types';
import { CharacterCard } from '@/hooks/Mapper/components/ui-kit';

const renderValCharacterTemplate = (row: TrackingCharacter | undefined) => {
  if (!row) {
    return <div className="h-[26px] flex items-center">Character is not selected</div>;
  }

  return (
    <div className="py-1">
      <CharacterCard compact showShipName={false} showSystem={false} isOwn {...row.character} />
    </div>
  );
};

const renderCharacterTemplate = (row: TrackingCharacter | undefined) => {
  if (!row) {
    return <div className="h-[33px] flex items-center">Character is not selected</div>;
  }

  return <CharacterCard showShipName={false} showSystem={false} isOwn {...row.character} />;
};

export const TrackingSettings = () => {
  // const [selectedMain, setSelectedMain] = useState(undefined);
  const [selectedFollow, setSelectedFollow] = useState<TrackingCharacter>();

  const {
    outCommand,
    data: { trackingCharactersData },
  } = useMapRootState();

  const characters = useMemo(() => trackingCharactersData ?? [], [trackingCharactersData]);
  // const refVars = useRef({ characters });
  // refVars.current = { characters };

  useEffect(() => {
    const followed = characters.find(x => x.followed);
    if (!followed) {
      return;
    }

    setSelectedFollow(followed);
  }, [characters]);

  const handleFollowToggle = useCallback(
    async (characterId: string) => {
      try {
        await outCommand({
          type: OutCommand.toggleFollow,
          data: { character_id: characterId },
        });
      } catch (error) {
        console.error('Error toggling follow:', error);
      }
    },
    [outCommand],
  );

  const handleSelectFollowed = useCallback(
    async (e: TrackingCharacter) => {
      await handleFollowToggle(e.character.eve_id);
    },
    [handleFollowToggle],
  );

  return (
    <div className="w-full h-full flex flex-col gap-1">
      {/* TODO unblock it when will done BE part of Main character select */}
      {/*<div className="flex items-center justify-between gap-2 mx-2">*/}
      {/*  <label className="text-stone-400 text-[13px] select-none">Main character</label>*/}
      {/*  <Dropdown*/}
      {/*    options={characters}*/}
      {/*    value={selectedMain}*/}
      {/*    onChange={e => setSelectedMain(e.value)}*/}
      {/*    className="w-[230px]"*/}
      {/*    itemTemplate={renderCharacterTemplate}*/}
      {/*    valueTemplate={renderValCharacterTemplate}*/}
      {/*  />*/}
      {/*</div>*/}

      <div className="flex items-center justify-between gap-2 mx-2">
        <label className="text-stone-400 text-[13px] select-none">Following character</label>
        <Dropdown
          options={characters}
          value={selectedFollow}
          onChange={e => handleSelectFollowed(e.value)}
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
