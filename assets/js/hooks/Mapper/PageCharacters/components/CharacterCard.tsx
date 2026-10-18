import clsx from 'clsx';
import {
  SystemViewStandalone,
  WdEveEntityPortrait,
  WdEveEntityPortraitSize,
  WdEveEntityPortraitType,
} from '@/hooks/Mapper/components/ui-kit';
import { EMPTY_VALUE } from '../constants';
import type { PageCharacter } from '../types';
import { formatWalletBalance, getCharacterPortraitUrl, getShipRenderUrl } from '../utils';
import styles from './CharacterCard.module.scss';

export interface CharacterCardProps {
  character: PageCharacter;
  showBalance: boolean;
  deleting: boolean;
  onAuthorize(character: PageCharacter): void;
  onDelete(character: PageCharacter): void;
}

export const CharacterCard = ({ character, showBalance, deleting, onAuthorize, onDelete }: CharacterCardProps) => {
  const walletVisible = showBalance && character.show_wallet_balance;

  return (
    <article className={styles.card}>
      <div className="relative aspect-[6/5] overflow-hidden bg-stone-900">
        <img
          src={getCharacterPortraitUrl(character.eve_id)}
          alt={character.name}
          className={clsx(styles.portraitImage, {
            [styles.invalidPortrait]: character.invalid_token,
          })}
        />
        <div className={styles.entityLogos}>
          <WdEveEntityPortrait
            type={WdEveEntityPortraitType.corporation}
            eveId={character.corporation_id.toString()}
            size={WdEveEntityPortraitSize.w33}
            className={styles.entityLogo}
          />
          {character.alliance_id && (
            <WdEveEntityPortrait
              type={WdEveEntityPortraitType.alliance}
              eveId={character.alliance_id.toString()}
              size={WdEveEntityPortraitSize.w33}
              className={styles.entityLogo}
            />
          )}
        </div>
        {character.ship_type_id && (
          <div className={styles.blueprint}>
            <div className={styles.blueprintGrid} />
            <div className={styles.blueprintGlow} />
            <img src={getShipRenderUrl(character.ship_type_id)} alt="" className={styles.shipImage} />
            <span className={styles.shipName} title={character.ship_name ?? EMPTY_VALUE}>
              {character.ship_name ?? EMPTY_VALUE}
            </span>
          </div>
        )}
        {character.invalid_token && (
          <span
            className={styles.tokenStatus}
            title="Character token has expired. Refresh authorization to resume tracking."
          >
            <span className={styles.tokenText}>Token needs refresh</span>
            <i className="pi pi-exclamation-triangle text-lg leading-none" aria-hidden="true" />
          </span>
        )}
        <div className={styles.nameOverlay}>
          <h2 className="truncate text-base font-semibold text-orange-400">{character.name}</h2>
        </div>
      </div>

      <dl className={styles.details}>
        <dt className="flex h-6 items-center text-stone-600">Corporation</dt>
        <dd className={styles.detailValue}>
          <span className="truncate">
            {character.corporation_name ?? EMPTY_VALUE}
            {character.corporation_ticker && ` [${character.corporation_ticker}]`}
          </span>
        </dd>
        <dt className="flex h-6 items-center text-stone-600">Alliance</dt>
        <dd className={styles.detailValue}>
          <span className="truncate">{character.alliance_name ?? EMPTY_VALUE}</span>
        </dd>
        <dt className="flex h-6 items-center text-stone-600">Location</dt>
        <dd className={styles.locationValue}>
          {character.system_info && (
            <SystemViewStandalone
              {...character.system_info}
              compact
              hideRegion
              className="min-w-0 justify-end overflow-hidden"
              nameClassName="truncate !text-stone-400"
            />
          )}
          {!character.system_info && <span className="truncate">{character.location_name ?? EMPTY_VALUE}</span>}
        </dd>
        {walletVisible && (
          <>
            <dt className="flex h-6 items-center text-stone-600">Balance</dt>
            <dd className={styles.balanceValue}>{formatWalletBalance(character.wallet_balance)}</dd>
          </>
        )}
      </dl>

      <div className={styles.toolbar}>
        <div className="flex items-center gap-0.5">
          <button
            type="button"
            className={clsx(styles.actionButton, styles.refreshButton)}
            aria-label={`Refresh authorization for ${character.name}`}
            disabled={deleting}
            onClick={() => onAuthorize(character)}
          >
            <i className="pi pi-refresh text-xs" aria-hidden="true" />
          </button>
          <button
            type="button"
            className={clsx(styles.actionButton, styles.deleteButton)}
            aria-label={`Delete ${character.name}`}
            disabled={deleting}
            onClick={() => onDelete(character)}
          >
            <i className={clsx('pi text-xs', deleting ? 'pi-spin pi-spinner' : 'pi-trash')} aria-hidden="true" />
          </button>
        </div>
      </div>
    </article>
  );
};
