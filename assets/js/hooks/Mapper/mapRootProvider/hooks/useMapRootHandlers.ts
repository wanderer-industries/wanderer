import { ForwardedRef, useImperativeHandle } from 'react';
import {
  CommandAddConnections,
  CommandAddSystems,
  CommandCharacterAdded,
  CommandCharacterRemoved,
  CommandCharactersUpdated,
  CommandCharacterUpdated,
  CommandInit,
  CommandMapUpdated,
  CommandPresentCharacters,
  CommandRemoveConnections,
  CommandRemoveSystems,
  CommandRoutes,
  Commands,
  CommandSignaturesUpdated,
  CommandUpdateConnection,
  CommandUpdateSystems,
  MapHandlers,
} from '@/hooks/Mapper/types/mapHandlers.ts';

import {
  useCommandsCharacters,
  useCommandsConnections,
  useCommandsSystems,
  useMapInit,
  useMapUpdated,
  useRoutes,
} from './api';

import { emitMapEvent } from '@/hooks/Mapper/events';

export const useMapRootHandlers = (ref: ForwardedRef<MapHandlers>) => {
  const mapInit = useMapInit();
  const { addSystems, removeSystems, updateSystems, updateSystemSignatures } = useCommandsSystems();
  const { addConnections, removeConnections, updateConnection } = useCommandsConnections();
  const { charactersUpdated, characterAdded, characterRemoved, characterUpdated, presentCharacters } =
    useCommandsCharacters();
  const mapUpdated = useMapUpdated();
  const mapRoutes = useRoutes();

  useImperativeHandle(
    ref,
    () => {
      return {
        command(type, data) {
          switch (type) {
            case Commands.init: // USED
              mapInit(data as CommandInit);
              break;
            case Commands.addSystems: // USED
              addSystems(data as CommandAddSystems);
              break;
            case Commands.updateSystems: // USED
              updateSystems(data as CommandUpdateSystems);
              break;
            case Commands.removeSystems: // USED
              removeSystems(data as CommandRemoveSystems);
              break;
            case Commands.addConnections: // USED
              addConnections(data as CommandAddConnections);
              break;
            case Commands.removeConnections: // USED
              removeConnections(data as CommandRemoveConnections);
              break;
            case Commands.updateConnection: // USED
              updateConnection(data as CommandUpdateConnection);
              break;
            case Commands.charactersUpdated: // USED
              charactersUpdated(data as CommandCharactersUpdated);
              break;
            case Commands.characterAdded: // USED
              characterAdded(data as CommandCharacterAdded);
              break;
            case Commands.characterRemoved: // USED
              characterRemoved(data as CommandCharacterRemoved);
              break;
            case Commands.characterUpdated: // USED
              characterUpdated(data as CommandCharacterUpdated);
              break;
            case Commands.presentCharacters: // USED
              presentCharacters(data as CommandPresentCharacters);
              break;
            case Commands.mapUpdated: // USED
              mapUpdated(data as CommandMapUpdated);
              break;
            case Commands.routes:
              mapRoutes(data as CommandRoutes);
              break;

            case Commands.signaturesUpdated: // USED
              updateSystemSignatures(data as CommandSignaturesUpdated);
              break;

            case Commands.linkSignatureToSystem: // USED
              // do nothing here
              break;

            case Commands.centerSystem: // USED
              // do nothing here
              break;

            case Commands.selectSystem: // USED
              // do nothing here
              break;

            case Commands.killsUpdated:
              // do nothing here
              break;

            default:
              console.warn(`JOipP Interface handlers: Unknown command: ${type}`, data);
              break;
          }

          emitMapEvent({ name: type, data });
        },
      };
    },
    [],
  );
};
