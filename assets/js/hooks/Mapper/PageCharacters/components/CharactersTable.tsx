import clsx from 'clsx';
import {
  SystemViewStandalone,
  WdEveEntityPortrait,
  WdEveEntityPortraitSize,
  WdEveEntityPortraitType,
} from '@/hooks/Mapper/components/ui-kit';
import { EMPTY_VALUE } from '../constants';
import type { PageCharacter } from '../types';
import { formatWalletBalance } from '../utils';
import styles from './CharactersTable.module.scss';

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
    <div className="overflow-hidden border border-white/10 bg-stone-950/80">
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

      <div className="overflow-x-auto">
        <table className="w-full min-w-[820px] border-collapse text-left text-sm">
          <thead className={styles.tableHeader}>
            <tr>
              <th className="px-3 py-2 font-medium">Character</th>
              <th className="px-3 py-2 font-medium">Corporation</th>
              <th className="px-3 py-2 font-medium">Alliance</th>
              <th className="px-3 py-2 font-medium">Location</th>
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

              return (
                <tr key={character.id} className="group transition hover:bg-stone-900/60">
                  <td className="px-3 py-1">
                    <div className="flex items-center gap-2">
                      <WdEveEntityPortrait
                        type={WdEveEntityPortraitType.character}
                        eveId={character.eve_id}
                        size={WdEveEntityPortraitSize.w33}
                        className="!border-white/10"
                      />
                      <span className={styles.characterName}>
                        {character.name}
                        {character.invalid_token && (
                          <i className="pi pi-exclamation-triangle text-xs text-red-400" title="Invalid token" />
                        )}
                      </span>
                    </div>
                  </td>
                  <td className="px-3 py-1 text-[13px] text-stone-400">
                    <div className="flex items-center gap-2">
                      <WdEveEntityPortrait
                        type={WdEveEntityPortraitType.corporation}
                        eveId={character.corporation_id.toString()}
                        size={WdEveEntityPortraitSize.w33}
                        className="!border-white/10 opacity-80"
                      />
                      <span className="truncate">{character.corporation_name ?? EMPTY_VALUE}</span>
                    </div>
                  </td>
                  <td className="px-3 py-1 text-[13px] text-stone-400">
                    <div className="flex items-center gap-2">
                      {character.alliance_id && (
                        <WdEveEntityPortrait
                          type={WdEveEntityPortraitType.alliance}
                          eveId={character.alliance_id.toString()}
                          size={WdEveEntityPortraitSize.w33}
                          className="!border-white/10 opacity-80"
                        />
                      )}
                      <span className="truncate">{character.alliance_name ?? EMPTY_VALUE}</span>
                    </div>
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
                  <td className="px-3 py-1 text-[13px] text-stone-400">{character.ship_name ?? EMPTY_VALUE}</td>
                  {showBalances && (
                    <td className="px-3 py-1 text-right text-stone-400">
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
