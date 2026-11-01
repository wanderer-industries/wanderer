import clsx from 'clsx';
import styles from './AddCharacterCard.module.scss';

const DEFAULT_CHARACTER_PORTRAIT_URL = 'https://images.evetech.net/characters/1/portrait?size=256';

export interface AddCharacterCardProps {
  onClick(): void;
}

export const AddCharacterCard = ({ onClick }: AddCharacterCardProps) => {
  return (
    <button type="button" className={styles.card} onClick={onClick}>
      <div className="relative aspect-[6/5] w-full overflow-hidden bg-stone-900">
        <img src={DEFAULT_CHARACTER_PORTRAIT_URL} alt="" className={styles.portraitImage} />
        <div className="absolute inset-0 bg-gradient-to-t from-black via-black/30 to-transparent" />
        <span className="absolute inset-0 flex items-center justify-center">
          <span className={styles.addIcon}>
            <i className="pi pi-plus" aria-hidden="true" />
          </span>
        </span>
        <div className="absolute inset-x-0 bottom-0 px-4 pb-4 pt-12">
          <h2 className="text-base font-semibold text-white">Authorize character</h2>
          <p className="mt-1 text-xs text-stone-400">Connect another capsuleer through EVE Online SSO</p>
        </div>
      </div>

      <div className={styles.details}>
        <div>
          <i className={clsx('pi pi-user-plus', styles.userIcon)} aria-hidden="true" />
          <p className="text-sm font-medium text-stone-300">Add character</p>
          <p className="mt-1 text-xs text-stone-500">Authorization opens through EVE Online SSO.</p>
        </div>
      </div>
    </button>
  );
};
