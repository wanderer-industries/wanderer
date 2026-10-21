import { useEffect, useMemo, useState } from 'react';
import clsx from 'clsx';
import { WdButton, WdConfirmDialog, WdDialog, WdInputText } from '@/hooks/Mapper/components/ui-kit';
import type { PageCharacter, PageCharactersViewMode } from './types';
import { PageCharactersStatus } from './types';
import { usePageCharacters } from './PageCharactersProvider';
import { AddCharacterCard } from './components/AddCharacterCard';
import { CharacterCard } from './components/CharacterCard';
import { CharactersTable } from './components/CharactersTable';
import { EveCharactersView } from './components/EveCharactersView';
import styles from './PageCharactersPage.module.scss';

interface ViewModeOption {
  mode: PageCharactersViewMode;
  icon: string;
  label: string;
  title: string;
}

interface AuthorizationScope {
  label: string;
  value: string;
}

const VIEW_MODE_OPTIONS: ReadonlyArray<ViewModeOption> = [
  { mode: 'cards', icon: 'pi-th-large', label: 'Card view', title: 'Cards' },
  { mode: 'table', icon: 'pi-list', label: 'Table view', title: 'Table' },
  { mode: 'eve', icon: 'pi-id-card', label: 'EVE character selection view', title: 'EVE character selection' },
];

const DEFAULT_AUTHORIZATION_SCOPES: ReadonlyArray<AuthorizationScope> = [
  { label: 'Read current location', value: 'esi-location.read_location.v1' },
  { label: 'Read active ship', value: 'esi-location.read_ship_type.v1' },
  { label: 'Read online status', value: 'esi-location.read_online.v1' },
  { label: 'Set navigation waypoints', value: 'esi-ui.write_waypoint.v1' },
  { label: 'Search structures', value: 'esi-search.search_structures.v1' },
];

const WALLET_AUTHORIZATION_SCOPE: AuthorizationScope = {
  label: 'Read character wallet',
  value: 'esi-wallet.read_character_wallet.v1',
};

export interface PageCharactersPageProps {}

export const PageCharactersPage = (_props: PageCharactersPageProps) => {
  const {
    status,
    error,
    characters,
    filteredCharacters,
    walletTrackingEnabled,
    query,
    viewMode,
    showBalances,
    promoHidden,
    deletingCharacterId,
    setQuery,
    setViewMode,
    setShowBalances,
    setPromoHidden,
    authorizeCharacter,
    deleteCharacter,
    refresh,
  } = usePageCharacters();
  const [authorizeOpen, setAuthorizeOpen] = useState(false);
  const [trackWallet, setTrackWallet] = useState(false);
  const [deleteTarget, setDeleteTarget] = useState<PageCharacter | null>(null);
  const isEveView = viewMode === 'eve';
  const isTableView = viewMode === 'table';
  const isDeleting = deleteTarget !== null && deletingCharacterId === deleteTarget.id;

  useEffect(() => {
    if (!deleteTarget) {
      return;
    }

    const characterStillExists = characters.some(character => character.id === deleteTarget.id);
    if (!characterStillExists) {
      setDeleteTarget(null);
    }
  }, [characters, deleteTarget]);

  const characterCountLabel = useMemo(() => {
    const visibleCount = filteredCharacters.length;
    if (!query.trim()) {
      return `${characters.length} linked`;
    }
    return `${visibleCount} of ${characters.length}`;
  }, [characters.length, filteredCharacters.length, query]);

  const hidePromo = () => {
    setPromoHidden(true);
  };

  const openAuthorize = (_character?: PageCharacter) => {
    setTrackWallet(false);
    setAuthorizeOpen(true);
  };

  const submitAuthorization = async () => {
    await authorizeCharacter(trackWallet);
  };

  const confirmDelete = () => {
    if (!deleteTarget) {
      return;
    }

    void deleteCharacter(deleteTarget.id, deleteTarget.name);
  };

  const closeDeleteDialog = () => {
    if (!isDeleting) {
      setDeleteTarget(null);
    }
  };

  const authorizeFooter = (
    <div className="flex flex-col items-center gap-3 sm:flex-row sm:justify-end">
      <WdButton text label="Cancel" onClick={() => setAuthorizeOpen(false)} />
      <button
        type="button"
        className={clsx('login-red-glow group', styles.eveLoginButton)}
        onClick={submitAuthorization}
      >
        <span className={clsx('animate-rotate', styles.eveLoginBorder)} />
        <span className={styles.eveLoginContent}>
          <img
            src="https://web.ccpgamescdn.com/eveonlineassets/developers/eve-sso-login-black-large.png"
            alt="Log in with EVE Online"
            className="h-[40px] w-[220px]"
          />
        </span>
      </button>
    </div>
  );

  if (status === PageCharactersStatus.loading) {
    return (
      <div className="flex h-full items-center justify-center text-stone-400" role="status">
        <i className="pi pi-spin pi-spinner mr-3 text-xl" aria-hidden="true" />
        Loading characters…
      </div>
    );
  }

  return (
    <div
      className={clsx(styles.page, {
        maps_bg: isEveView,
        [styles.evePage]: isEveView,
        [styles.defaultPage]: !isEveView,
      })}
    >
      <header
        className={clsx(styles.header, {
          [styles.eveHeader]: isEveView,
          [styles.defaultHeader]: !isEveView,
        })}
      >
        <div className={styles.headerContent}>
          <div>
            <div className="flex items-center gap-3">
              <h1 className="text-xl font-semibold text-white">Characters</h1>
              <span className="text-xs text-stone-500">{characterCountLabel}</span>
            </div>
            <p className="mt-1 text-xs text-stone-500">Manage linked EVE characters and authorization state.</p>
          </div>

          <div className="flex flex-wrap items-center gap-4">
            {walletTrackingEnabled && (
              <label className={styles.balanceToggle}>
                <span>Balances</span>
                <input
                  type="checkbox"
                  className={styles.balanceInput}
                  checked={showBalances}
                  onChange={event => setShowBalances(event.target.checked)}
                />
                <span className={styles.balanceSwitch} />
              </label>
            )}
            <span className="relative min-w-[240px] flex-1 xl:flex-none">
              <i className={clsx('pi pi-search', styles.searchIcon)} aria-hidden="true" />
              <WdInputText
                value={query}
                onChange={event => setQuery(event.target.value)}
                placeholder="Search characters"
                aria-label="Search characters"
                className="!h-9 w-full !pl-9"
              />
            </span>
            <div className={styles.viewSelector}>
              {VIEW_MODE_OPTIONS.map(option => (
                <button
                  key={option.mode}
                  type="button"
                  className={clsx(styles.viewButton, {
                    [styles.activeViewButton]: viewMode === option.mode,
                    [styles.idleViewButton]: viewMode !== option.mode,
                  })}
                  aria-label={option.label}
                  aria-pressed={viewMode === option.mode}
                  title={option.title}
                  onClick={() => setViewMode(option.mode)}
                >
                  <i className={clsx('pi text-sm', option.icon)} aria-hidden="true" />
                </button>
              ))}
            </div>
          </div>
        </div>
      </header>

      <div
        className={clsx('min-h-0 flex-1', {
          'overflow-hidden': isTableView,
          'overflow-y-auto': !isTableView,
        })}
      >
        <main className={clsx(styles.main, { [styles.tableMain]: isTableView })}>
          {error && (
            <div className={styles.errorBanner} role="alert">
              <span>{error}</span>
              <WdButton text size="small" label="Retry" icon="pi pi-refresh" onClick={refresh} />
            </div>
          )}

          {!promoHidden && !isEveView && (
            <aside className={styles.promoBanner}>
              <div className="flex items-center gap-3 text-sm text-stone-300">
                <i className="pi pi-gift text-emerald-400" aria-hidden="true" />
                <span>
                  Support development with promo code{' '}
                  <code className="bg-stone-800 px-1.5 py-0.5 font-mono text-xs text-emerald-400">WANDERER</code> at the
                  official EVE Online Store.
                </span>
                <a
                  href="https://store.eveonline.com/"
                  target="_blank"
                  rel="noreferrer"
                  className="text-emerald-400 hover:text-emerald-300"
                >
                  Open store <i className="pi pi-external-link text-xs" aria-hidden="true" />
                </a>
              </div>
              <WdButton text size="small" icon="pi pi-times" aria-label="Hide promotion" onClick={hidePromo} />
            </aside>
          )}

          {viewMode === 'cards' && (
            <div className="grid grid-cols-1 justify-center gap-4 sm:grid-cols-[repeat(auto-fill,minmax(300px,350px))]">
              <AddCharacterCard onClick={() => openAuthorize()} />
              {filteredCharacters.map(character => (
                <CharacterCard
                  key={character.id}
                  character={character}
                  showBalance={showBalances}
                  deleting={deletingCharacterId === character.id}
                  onAuthorize={openAuthorize}
                  onDelete={setDeleteTarget}
                />
              ))}
            </div>
          )}

          {viewMode === 'table' && (
            <CharactersTable
              characters={filteredCharacters}
              showBalances={showBalances}
              deletingCharacterId={deletingCharacterId}
              onAddCharacter={() => openAuthorize()}
              onAuthorize={openAuthorize}
              onDelete={setDeleteTarget}
            />
          )}

          {isEveView && (
            <EveCharactersView
              characters={filteredCharacters}
              showBalances={showBalances}
              deletingCharacterId={deletingCharacterId}
              onAddCharacter={() => openAuthorize()}
              onAuthorize={openAuthorize}
              onDelete={setDeleteTarget}
            />
          )}
        </main>
      </div>

      <WdDialog
        header="Authorize character"
        visible={authorizeOpen}
        modal
        className={styles.authorizeDialog}
        onHide={() => setAuthorizeOpen(false)}
        footer={authorizeFooter}
      >
        <div className="space-y-5 text-sm text-stone-300">
          <p>The character will be linked to your current Wanderer account through EVE Online SSO.</p>

          <div>
            <div className="mb-2 flex items-end justify-between gap-4">
              <h3 className="text-xs font-medium uppercase tracking-wider text-stone-300">Requested ESI scopes</h3>
              <span className="text-[10px] text-stone-600">Required scopes cannot be changed</span>
            </div>

            <div className="divide-y divide-white/5 border border-white/10 bg-black/20">
              {DEFAULT_AUTHORIZATION_SCOPES.map(scope => (
                <label key={scope.value} className={styles.requiredScope}>
                  <input
                    type="checkbox"
                    checked
                    readOnly
                    disabled
                    className="mt-0.5 h-4 w-4 flex-none accent-orange-400 disabled:opacity-70"
                  />
                  <span className="min-w-0">
                    <span className="block text-xs text-stone-300">{scope.label}</span>
                    <code className="mt-0.5 block text-[10px] text-stone-600">{scope.value}</code>
                  </span>
                </label>
              ))}

              {walletTrackingEnabled && (
                <label className={styles.optionalScope}>
                  <input
                    type="checkbox"
                    checked={trackWallet}
                    className="mt-0.5 h-4 w-4 flex-none accent-orange-400"
                    onChange={event => setTrackWallet(event.target.checked)}
                  />
                  <span className="min-w-0">
                    <span className="block text-xs text-stone-200">{WALLET_AUTHORIZATION_SCOPE.label}</span>
                    <code className="mt-0.5 block text-[10px] text-stone-500">{WALLET_AUTHORIZATION_SCOPE.value}</code>
                    <span className="mt-1 block text-[11px] text-stone-500">
                      Optional. Allows Wanderer to display this character&apos;s wallet balance.
                    </span>
                  </span>
                </label>
              )}
            </div>
          </div>
        </div>
      </WdDialog>

      <WdConfirmDialog
        header="Delete character"
        visible={deleteTarget !== null}
        confirmLabel="Confirm Delete"
        confirmIcon="pi pi-trash"
        loading={isDeleting}
        onConfirm={confirmDelete}
        onCancel={closeDeleteDialog}
      >
        Remove <strong className="text-white">{deleteTarget?.name}</strong> from your account and stop tracking it on
        maps?
      </WdConfirmDialog>
    </div>
  );
};
