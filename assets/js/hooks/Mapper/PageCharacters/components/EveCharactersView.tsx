import { useEffect, useState } from 'react';
import clsx from 'clsx';
import type { PageCharacter } from '../types';
import { EveAddCharacterCard } from './EveAddCharacterCard';
import { EveCharacterCard } from './EveCharacterCard';
import styles from './EveCharactersView.module.scss';

export interface EveCharactersViewProps {
  characters: PageCharacter[];
  showBalances: boolean;
  deletingCharacterId: string | null;
  onAddCharacter(): void;
  onAuthorize(character: PageCharacter): void;
  onDelete(character: PageCharacter): void;
}

export const EveCharactersView = ({
  characters,
  showBalances,
  deletingCharacterId,
  onAddCharacter,
  onAuthorize,
  onDelete,
}: EveCharactersViewProps) => {
  const [selectedCharacterId, setSelectedCharacterId] = useState<string | null>(characters[0]?.id ?? null);

  useEffect(() => {
    const selectionStillExists = characters.some(character => character.id === selectedCharacterId);
    if (selectedCharacterId !== null && !selectionStillExists) {
      setSelectedCharacterId(characters[0]?.id ?? null);
    }
  }, [characters, selectedCharacterId]);

  return (
    <section className={styles.view}>
      <div className={styles.topGlow} />
      <div className={styles.viewTitle}>Select a capsuleer</div>

      <div className={styles.cardsLayout}>
        <EveAddCharacterCard onClick={onAddCharacter} />
        <div className={clsx('custom-scrollbar', styles.viewport)}>
          <div className={styles.characterRail}>
            {characters.map((character, index) => (
              <EveCharacterCard
                key={character.id}
                character={character}
                stackIndex={characters.length - index + 1}
                active={selectedCharacterId === character.id}
                showBalance={showBalances}
                deleting={deletingCharacterId === character.id}
                onSelect={setSelectedCharacterId}
                onAuthorize={onAuthorize}
                onDelete={onDelete}
              />
            ))}
          </div>
        </div>
      </div>
    </section>
  );
};
