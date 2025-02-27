import { SignatureGroup, SystemSignature } from '@/hooks/Mapper/types';
import { renderIcon } from '@/hooks/Mapper/components/mapInterface/widgets/SystemSignatures/renders';

export interface SignatureViewProps {
  showCharacterPortrait?: boolean;
}

export const SignatureView = (sig: SignatureViewProps & SystemSignature) => {
  const { showCharacterPortrait = false } = sig;
  const isWormhole = sig?.group === SignatureGroup.Wormhole;

  return (
    <div className="flex flex-col gap-2">
      <div className="flex gap-2 items-center">
        {renderIcon(sig)}
        <div>{sig?.eve_id}</div>
        <div>{isWormhole ? SignatureGroup.Wormhole : sig?.group ?? SignatureGroup.CosmicSignature}</div>
        {!isWormhole && <div>{sig?.name}</div>}
        {showCharacterPortrait && sig.character_eve_id && (
          <div className="flex items-center gap-1 ml-2 pl-2 border-l border-stone-700">
            <img
              src={`https://images.evetech.net/characters/${sig.character_eve_id}/portrait`}
              alt={sig.character_name || 'Character portrait'}
              className="w-5 h-5 rounded-sm border border-stone-700"
            />
            <div className="text-xs text-stone-300">{sig.character_name || 'Unknown character'}</div>
          </div>
        )}
      </div>
    </div>
  );
};
