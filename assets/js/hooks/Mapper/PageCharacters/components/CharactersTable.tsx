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
import { formatWalletBalance, getDockedAt, isUnknownStructure } from '../utils';
import styles from './CharactersTable.module.scss';

interface CharacterStatusConfig {
  iconClassName: string;
  label: string;
  tooltip: string;
}

const ONLINE_STATUS: CharacterStatusConfig = {
  iconClassName: 'pi pi-wifi text-sm text-emerald-400',
  label: 'Online',
  tooltip: 'Online — live character data is being tracked.',
};

const OFFLINE_STATUS: CharacterStatusConfig = {
  iconClassName: 'pi pi-wifi text-sm text-stone-600',
  label: 'Offline',
  tooltip: 'Offline — authorization token is valid.',
};

const INVALID_TOKEN_STATUS: CharacterStatusConfig = {
  iconClassName: 'pi pi-exclamation-triangle text-sm text-red-400',
  label: 'Token expired',
  tooltip: 'Token expired — refresh authorization to resume tracking.',
};

const getCharacterStatus = (character: PageCharacter): CharacterStatusConfig => {
  if (character.invalid_token) return INVALID_TOKEN_STATUS;
  if (character.online) return ONLINE_STATUS;
  return OFFLINE_STATUS;
};

export interface CharactersTableProps {
  characters: PageCharacter[];
  showBalances: boolean;
  deletingCharacterId: string | null;
  onAddCharacter(): void;
  onAuthorize(character: PageCharacter): void;
  onDelete(character: PageCharacter): void;
}

export const CharactersTable = ({
  characters,
  showBalances,
  deletingCharacterId,
  onAddCharacter,
  onAuthorize,
  onDelete,
}: CharactersTableProps) => {
  return (
    <div className={clsx(styles.tableRoot, 'overflow-hidden border border-white/10 bg-stone-950/80')}>
      <button type="button" className={styles.authorizeButton} onClick={onAddCharacter}>
        <span className={styles.authorizeIcon}>
          <i className="pi pi-plus" aria-hidden="true" />
        </span>
        <span className="min-w-0">
          <span className="block truncate font-medium text-orange-400">Authorize character</span>
          <span className="block truncate text-xs text-stone-500">
            Connect another capsuleer through EVE Online SSO
          </span>
        </span>
      </button>

      <div className={clsx('custom-scrollbar', styles.tableViewport)}>
        <table className="w-full min-w-[860px] border-collapse text-left text-sm">
          <thead className={styles.tableHeader}>
            <tr>
              <th className="w-10 px-1 py-2 text-center font-medium">
                <span className="sr-only">Status</span>
              </th>
              <th className="w-[18.5rem] max-w-[18.5rem] px-3 py-2 font-medium">Character</th>
              <th className="px-3 py-2 font-medium">Alliance</th>
              <th className="px-3 py-2 font-medium">Location</th>
              <th className="px-3 py-2 font-medium">Docked at</th>
              <th className="px-3 py-2 font-medium">Ship</th>
              {showBalances && <th className="px-3 py-2 text-right font-medium">Balance</th>}
              <th className="w-20 px-3 py-2">
                <span className="sr-only">Actions</span>
              </th>
            </tr>
          </thead>
          <tbody className="divide-y divide-white/5">
            {characters.map(character => {
              const showBalance = showBalances && character.show_wallet_balance;
              const status = getCharacterStatus(character);
              const dockedAt = getDockedAt(character);
              const unknownStructure = isUnknownStructure(character);

              return (
                <tr key={character.id} className="group transition hover:bg-stone-900/60">
                  <td className="w-10 px-1 py-1 text-center">
                    <WdTooltipWrapper
                      content={status.tooltip}
                      position={TooltipPosition.top}
                      wrapperClassName="flex h-8 w-8 items-center justify-center"
                    >
                      <span className="flex items-center justify-center" role="img" aria-label={status.label}>
                        <i className={status.iconClassName} aria-hidden="true" />
                      </span>
                    </WdTooltipWrapper>
                  </td>
                  <td className="w-[18.5rem] max-w-[18.5rem] px-3 py-1">
                    <div className="flex min-w-0 items-center gap-1">
                      <WdEveEntityPortrait
                        type={WdEveEntityPortraitType.character}
                        eveId={character.eve_id}
                        size={WdEveEntityPortraitSize.w33}
                        className="!border-white/10"
                      />
                      {character.corporation_id !== null && (
                        <WdTooltipWrapper
                          content={character.corporation_name ?? 'Unknown corporation'}
                          position={TooltipPosition.top}
                          wrapperClassName="flex"
                        >
                          <WdEveEntityPortrait
                            type={WdEveEntityPortraitType.corporation}
                            eveId={character.corporation_id.toString()}
                            size={WdEveEntityPortraitSize.w33}
                            className="!border-white/10 opacity-80"
                          />
                        </WdTooltipWrapper>
                      )}
                      <span className={clsx(styles.characterName, 'ml-1')}>{character.name}</span>
                    </div>
                  </td>
                  <td className="max-w-48 px-3 py-1 text-xs text-stone-500">
                    {character.alliance_id && (
                      <div className="flex items-center gap-2">
                        <WdTooltipWrapper
                          content={character.alliance_name ?? 'Unknown alliance'}
                          position={TooltipPosition.top}
                          wrapperClassName="flex"
                        >
                          <WdEveEntityPortrait
                            type={WdEveEntityPortraitType.alliance}
                            eveId={character.alliance_id.toString()}
                            size={WdEveEntityPortraitSize.w33}
                            className="!border-white/10 opacity-80"
                          />
                        </WdTooltipWrapper>
                        <span className="block truncate" title={character.alliance_name ?? undefined}>
                          {character.alliance_name ?? 'Unknown alliance'}
                        </span>
                      </div>
                    )}
                  </td>
                  <td className="px-3 py-1 text-stone-400">
                    {character.system_info && (
                      <SystemViewStandalone
                        {...character.system_info}
                        compact
                        hideRegion
                        className="min-w-0 overflow-hidden"
                        nameClassName="truncate !text-stone-400"
                      />
                    )}
                    {!character.system_info && <span>{character.location_name ?? EMPTY_VALUE}</span>}
                  </td>
                  <td
                    className={clsx('max-w-56 px-3 py-1 text-xs text-stone-500', {
                      [styles.unknownStructure]: unknownStructure,
                    })}
                  >
                    <span className="block truncate" title={dockedAt}>
                      {dockedAt}
                    </span>
                  </td>
                  <td className="px-3 py-1 text-xs text-stone-500">{character.ship_name ?? EMPTY_VALUE}</td>
                  {showBalances && (
                    <td className="px-3 py-1 text-right text-xs text-stone-500">
                      {showBalance ? formatWalletBalance(character.wallet_balance) : EMPTY_VALUE}
                    </td>
                  )}
                  <td className="px-3 py-1">
                    <div className="flex justify-end gap-0.5">
                      <button
                        type="button"
                        className={clsx(styles.actionButton, styles.refreshButton)}
                        aria-label={`Refresh authorization for ${character.name}`}
                        disabled={deletingCharacterId === character.id}
                        onClick={() => onAuthorize(character)}
                      >
                        <i className="pi pi-refresh text-xs" aria-hidden="true" />
                      </button>
                      <button
                        type="button"
                        className={clsx(styles.actionButton, styles.deleteButton)}
                        aria-label={`Delete ${character.name}`}
                        disabled={deletingCharacterId === character.id}
                        onClick={() => onDelete(character)}
                      >
                        <i
                          className={clsx(
                            'pi text-xs',
                            deletingCharacterId === character.id ? 'pi-spin pi-spinner' : 'pi-trash',
                          )}
                          aria-hidden="true"
                        />
                      </button>
                    </div>
                  </td>
                </tr>
              );
            })}
          </tbody>
        </table>
      </div>
    </div>
  );
};
