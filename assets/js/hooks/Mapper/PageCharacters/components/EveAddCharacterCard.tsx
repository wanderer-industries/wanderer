import clsx from 'clsx';
import styles from './EveCharactersView.module.scss';

const DEFAULT_CHARACTER_PORTRAIT_URL = 'https://images.evetech.net/characters/1/portrait?size=256';

export interface EveAddCharacterCardProps {
  onClick(): void;
}

export const EveAddCharacterCard = ({ onClick }: EveAddCharacterCardProps) => {
  return (
    <button type="button" className={styles.addCard} onClick={onClick}>
      <div className={styles.cardHeader}>Add character</div>

      <div className={clsx(styles.cardBody, styles.addCardBody)}>
        <div className={styles.portraitFrame}>
          <img src={DEFAULT_CHARACTER_PORTRAIT_URL} alt="" className={styles.addPortraitImage} />
          <div className="absolute inset-0 bg-gradient-to-t from-black/90 via-transparent to-black/30" />
          <div className="absolute inset-0 flex items-center justify-center">
            <span className={styles.addIcon}>
              <i className="pi pi-plus" aria-hidden="true" />
            </span>
          </div>
        </div>

        <div className={styles.addTitleBar}>Add character</div>

        <div className={styles.addDetails}>
          <div className={styles.addGrid} />
          <i className={clsx('pi pi-user-plus', styles.addUserIcon)} aria-hidden="true" />
          <span className="relative text-sm font-medium text-stone-200">Connect another capsuleer</span>
          <span className="relative mt-1 text-xs leading-5 text-stone-500">
            Authorization opens through EVE Online SSO.
          </span>
        </div>
      </div>
    </button>
  );
};
