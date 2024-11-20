import { ForwardedRef, useImperativeHandle, useRef } from 'react';
import {
  CommandAddConnections,
  CommandAddSystems,
  CommandCharacterAdded,
  CommandCharacterRemoved,
  CommandCharactersUpdated,
  CommandCharacterUpdated,
  CommandInit,
  CommandKillsUpdated,
  CommandMapUpdated,
  CommandPresentCharacters,
  CommandRemoveConnections,
  CommandRemoveSystems,
  Commands,
  CommandSelectSystem,
  CommandUpdateConnection,
  CommandUpdateSystems,
  MapHandlers,
} from '@/hooks/Mapper/types/mapHandlers.ts';

import {
  useCommandsCharacters,
  useCommandsConnections,
  useMapAddSystems,
  useMapCommands,
  useMapInit,
  useMapRemoveSystems,
  useMapUpdateSystems,
  useCenterSystem,
  useSelectSystem,
} from './api';
import { OnMapSelectionChange } from '@/hooks/Mapper/components/map/map.types.ts';

export const useMapHandlers = (ref: ForwardedRef<MapHandlers>, onSelectionChange: OnMapSelectionChange) => {
  const mapInit = useMapInit();
  const mapAddSystems = useMapAddSystems();
  const mapUpdateSystems = useMapUpdateSystems();
  const removeSystems = useMapRemoveSystems(onSelectionChange);
  const centerSystem = useCenterSystem();
  const selectSystem = useSelectSystem();

  const selectRef = useRef({ onSelectionChange });
  selectRef.current = { onSelectionChange };

  const { addConnections, removeConnections, updateConnection } = useCommandsConnections();
  const { mapUpdated, killsUpdated } = useMapCommands();
  const { charactersUpdated, presentCharacters, characterAdded, characterRemoved, characterUpdated } =
    useCommandsCharacters();

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
              setTimeout(() => mapAddSystems(data as CommandAddSystems), 100);
              break;
            case Commands.updateSystems:
              mapUpdateSystems(data as CommandUpdateSystems);
              break;
            case Commands.removeSystems:
              setTimeout(() => removeSystems(data as CommandRemoveSystems), 100);
              break;
            case Commands.addConnections:
              setTimeout(() => addConnections(data as CommandAddConnections), 100);
              break;
            case Commands.removeConnections:
              removeConnections(data as CommandRemoveConnections);
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
            case Commands.updateConnection:
              updateConnection(data as CommandUpdateConnection);
              break;
            case Commands.mapUpdated:
              mapUpdated(data as CommandMapUpdated);
              break;
            case Commands.killsUpdated:
              killsUpdated(data as CommandKillsUpdated);
              break;

            case Commands.centerSystem:
              setTimeout(() => {
                const systemId = `${data}`;
                centerSystem(systemId as CommandSelectSystem);
              }, 100);
              break;

            case Commands.selectSystem:
              setTimeout(() => {
                const systemId = `${data}`;
                selectRef.current.onSelectionChange({
                  systems: [systemId],
                  connections: [],
                });
                selectSystem(systemId as CommandSelectSystem);
              }, 100);
              break;

            case Commands.routes:
              // do nothing here
              break;

            case Commands.signaturesUpdated:
              // do nothing here
              break;

            case Commands.linkSignatureToSystem:
              // do nothing here
              break;

            default:
              console.warn(`Map handlers: Unknown command: ${type}`, data);
              break;
          }
        },
      };
    },
    [],
  );
};
