import type { CSSProperties, FocusEvent, KeyboardEvent, MouseEvent } from 'react';
import { useState } from 'react';
import clsx from 'clsx';
import {
  SystemViewStandalone,
  TooltipPosition,
  WdEveEntityPortrait,
  WdEveEntityPortraitSize,
  WdEveEntityPortraitType,
  WdTooltipWrapper,
} from '@/hooks/Mapper/components/ui-kit';
import { EMPTY_VALUE } from '../constants';
import type { PageCharacter } from '../types';
import {
  formatWalletBalance,
  getCharacterPortraitUrl,
  getDockedAt,
  getShipRenderUrl,
  isUnknownStructure,
} from '../utils';
import styles from './EveCharactersView.module.scss';

export interface EveCharacterCardProps {
  character: PageCharacter;
  stackIndex: number;
  active: boolean;
  showBalance: boolean;
  deleting: boolean;
  onSelect(characterId: string): void;
  onAuthorize(character: PageCharacter): void;
  onDelete(character: PageCharacter): void;
}

export const EveCharacterCard = ({
  character,
  stackIndex,
  active,
  showBalance,
  deleting,
  onSelect,
  onAuthorize,
  onDelete,
}: EveCharacterCardProps) => {
  const walletVisible = showBalance && character.show_wallet_balance;
  const dockedAt = getDockedAt(character);
  const unknownStructure = isUnknownStructure(character);
  const [toolbarVisible, setToolbarVisible] = useState(false);

  const selectCharacter = () => {
    onSelect(character.id);
  };

  const handleKeyDown = (event: KeyboardEvent<HTMLElement>) => {
    if (event.key === 'Enter' || event.key === ' ') {
      event.preventDefault();
      selectCharacter();
    }
  };

  const stopPropagation = (event: MouseEvent<HTMLElement>) => {
    event.stopPropagation();
  };

  const handleBlur = (event: FocusEvent<HTMLElement>) => {
    if (!event.currentTarget.contains(event.relatedTarget)) {
      setToolbarVisible(false);
    }
  };

  return (
    <article
      className={clsx(styles.characterCard, {
        [styles.active]: active,
        [styles.invalidToken]: character.invalid_token,
      })}
      style={{ zIndex: stackIndex }}
      role="button"
      tabIndex={0}
      aria-label={`${character.name} character card`}
      aria-pressed={active}
      onClick={selectCharacter}
      onKeyDown={handleKeyDown}
      onMouseEnter={() => setToolbarVisible(true)}
      onMouseLeave={() => setToolbarVisible(false)}
      onFocus={() => setToolbarVisible(true)}
      onBlur={handleBlur}
    >
      <div className={styles.cardHeader}>
        <span className="w-full truncate pr-14">{character.name}</span>
        <div
          className={clsx(styles.toolbar, {
            [styles.hiddenToolbar]: !toolbarVisible,
            [styles.visibleToolbar]: toolbarVisible,
          })}
          aria-hidden={!toolbarVisible}
        >
          <div className="flex items-center gap-0" onClick={stopPropagation}>
            <button
              type="button"
              className={clsx(styles.actionButton, styles.refreshButton)}
              aria-label={`Refresh authorization for ${character.name}`}
              disabled={deleting}
              tabIndex={toolbarVisible ? 0 : -1}
              onClick={() => onAuthorize(character)}
            >
              <i className="pi pi-refresh text-[11px]" aria-hidden="true" />
            </button>
            <button
              type="button"
              className={clsx(styles.actionButton, styles.deleteButton)}
              aria-label={`Delete ${character.name}`}
              disabled={deleting}
              tabIndex={toolbarVisible ? 0 : -1}
              onClick={() => onDelete(character)}
            >
              <i className={clsx('pi text-[11px]', deleting ? 'pi-spin pi-spinner' : 'pi-times')} aria-hidden="true" />
            </button>
          </div>
        </div>
      </div>

      <div className={styles.cardBody}>
        <div className={styles.portraitFrame}>
          <img src={getCharacterPortraitUrl(character.eve_id)} alt={character.name} className={styles.portraitImage} />
          <div className={styles.portraitShade} />
          <div className="absolute bottom-2 left-2 flex items-end gap-1.5">
            <WdTooltipWrapper content={character.corporation_name ?? 'Corporation'} position={TooltipPosition.top}>
              <WdEveEntityPortrait
                type={WdEveEntityPortraitType.corporation}
                eveId={character.corporation_id.toString()}
                size={WdEveEntityPortraitSize.w33}
                className={styles.entityLogo}
              />
            </WdTooltipWrapper>
            {character.alliance_id && (
              <WdTooltipWrapper content={character.alliance_name ?? 'Alliance'} position={TooltipPosition.top}>
                <WdEveEntityPortrait
                  type={WdEveEntityPortraitType.alliance}
                  eveId={character.alliance_id.toString()}
                  size={WdEveEntityPortraitSize.w33}
                  className={styles.entityLogo}
                />
              </WdTooltipWrapper>
            )}
          </div>
          {character.invalid_token && (
            <WdTooltipWrapper
              className="absolute bottom-3 right-3"
              content="Character token has expired. Refresh authorization to resume tracking."
              position={TooltipPosition.top}
            >
              <span className={styles.tokenStatus}>
                <span className="mb-[2px] font-mono text-[9px] uppercase leading-none tracking-[0.08em]">
                  Token needs refresh
                </span>
                <i className="pi pi-exclamation-triangle text-lg leading-none" aria-hidden="true" />
              </span>
            </WdTooltipWrapper>
          )}
          {!character.invalid_token && character.online && (
            <WdTooltipWrapper
              className="absolute bottom-3 right-3"
              content="Character is online and live data is being tracked."
              position={TooltipPosition.top}
            >
              <span className={styles.onlineStatus}>
                <span className="font-mono text-[11px] uppercase leading-none tracking-[0.08em]">Online</span>
                <i className="pi pi-wifi text-sm leading-none" aria-hidden="true" />
              </span>
            </WdTooltipWrapper>
          )}
        </div>

        <div className={styles.detailsPanel}>
          <div className={styles.detailRow}>
            <span className="flex-none text-stone-500">Corporation</span>
            <span className="ml-2 truncate" title={character.corporation_name ?? undefined}>
              {character.corporation_name ?? EMPTY_VALUE}
            </span>
          </div>
          <div className={styles.detailRow}>
            {character.alliance_name && <span className="flex-none text-stone-500">Alliance</span>}
            {character.alliance_name && (
              <span className="ml-2 truncate" title={character.alliance_name}>
                {character.alliance_name}
              </span>
            )}
          </div>
          <div className={styles.lastDetailRow}>
            {walletVisible && <span className="flex-none text-stone-500">Balance</span>}
            {walletVisible && <span className="ml-2 truncate">{formatWalletBalance(character.wallet_balance)}</span>}
          </div>
        </div>

        <div className={styles.shipPanel}>
          <div className={styles.shipGlow} aria-hidden="true" />
          <div className={styles.shipGrid} />
          {character.ship_type_id && (
            <img
              src={getShipRenderUrl(character.ship_type_id)}
              alt={character.ship_name ?? 'Current ship'}
              className={styles.shipImage}
            />
          )}
          {!character.ship_type_id && (
            <i className="pi pi-send relative -translate-y-[14px] text-4xl text-stone-700" aria-hidden="true" />
          )}
          <div className={styles.shipName}>{character.ship_name ?? EMPTY_VALUE}</div>
        </div>

        <div className={styles.locationPanel}>
          {character.system_info && (
            <SystemViewStandalone
              {...character.system_info}
              compact
              hideRegion
              className={styles.systemInfo}
              nameClassName="truncate"
              style={{ '--rf-system-view-compact-name-max-width': '170px' } as CSSProperties}
            />
          )}
          {!character.system_info && (
            <div className="w-full truncate text-stone-200" title={character.location_name ?? undefined}>
              {character.location_name ?? EMPTY_VALUE}
            </div>
          )}
          <div
            className={clsx('mt-0.5 w-full truncate text-stone-500', {
              '!text-stone-600': unknownStructure,
            })}
            title={dockedAt}
          >
            {dockedAt}
          </div>
        </div>
      </div>
    </article>
  );
};
