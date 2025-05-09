import { SignatureGroup, SystemSignature } from '@/hooks/Mapper/types';
import { renderIcon } from '@/hooks/Mapper/components/mapInterface/widgets/SystemSignatures/renders';
import { getCharacterPortraitUrl } from '@/hooks/Mapper/helpers';

export interface SignatureViewProps {
  signature: SystemSignature;
  showCharacterPortrait?: boolean;
}

export const SignatureView = ({ signature, showCharacterPortrait = false }: SignatureViewProps) => {
  const isWormhole = signature?.group === SignatureGroup.Wormhole;
  const hasCharacterInfo = showCharacterPortrait && signature.character_eve_id;
  const groupDisplay = isWormhole ? SignatureGroup.Wormhole : signature?.group ?? SignatureGroup.CosmicSignature;
  const characterName = signature.character_name || 'Unknown character';

  return (
    <div className="flex flex-col gap-2">
      <div className="flex gap-2 items-center px-2">
        {renderIcon(signature)}
        <div>{signature?.eve_id}</div>
        <div>{groupDisplay}</div>
        {!isWormhole && <div>{signature?.name}</div>}
        {hasCharacterInfo && (
          <div className="flex items-center gap-1 ml-2 pl-2 border-l border-stone-700">
            <img
              src={getCharacterPortraitUrl(signature.character_eve_id)}
              alt={characterName}
              className="w-5 h-5 rounded-sm border border-stone-700"
            />
            <div className="text-xs text-stone-300">{characterName}</div>
          </div>
        )}
      </div>
    </div>
  );
};
