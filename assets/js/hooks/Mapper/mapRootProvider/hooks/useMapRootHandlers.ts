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

export const useMapRootHandlers = (ref: ForwardedRef<MapHandlers>) => {
  const mapInit = useMapInit();
  const { addSystems, removeSystems, updateSystems } = useCommandsSystems();
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
            case Commands.init:
              mapInit(data as CommandInit);
              break;
            case Commands.addSystems:
              addSystems(data as CommandAddSystems);
              break;
            case Commands.updateSystems:
              updateSystems(data as CommandUpdateSystems);
              break;
            case Commands.removeSystems:
              removeSystems(data as CommandRemoveSystems);
              break;
            case Commands.addConnections:
              addConnections(data as CommandAddConnections);
              break;
            case Commands.removeConnections:
              removeConnections(data as CommandRemoveConnections);
              break;
            case Commands.updateConnection:
              updateConnection(data as CommandUpdateConnection);
              break;
            case Commands.charactersUpdated:
              charactersUpdated(data as CommandCharactersUpdated);
              break;
            case Commands.characterAdded:
              characterAdded(data as CommandCharacterAdded);
              break;
            case Commands.characterRemoved:
              characterRemoved(data as CommandCharacterRemoved);
              break;
            case Commands.characterUpdated:
              characterUpdated(data as CommandCharacterUpdated);
              break;
            case Commands.presentCharacters:
              presentCharacters(data as CommandPresentCharacters);
              break;
            case Commands.mapUpdated:
              mapUpdated(data as CommandMapUpdated);
              break;
            case Commands.routes:
              mapRoutes(data as CommandRoutes);
              break;

            case Commands.centerSystem:
              // do nothing here
              break;

            case Commands.selectSystem:
              // do nothing here
              break;

            case Commands.killsUpdated:
              // do nothing here
              break;

            default:
              console.warn(`JOipP Interface handlers: Unknown command: ${type}`, data);
              break;
          }
        },
      };
    },
    [],
  );
};
