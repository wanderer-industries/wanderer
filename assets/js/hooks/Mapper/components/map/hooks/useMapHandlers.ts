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
  CommandSelectSystems,
  CommandUpdateConnection,
  CommandUpdateSystems,
  MapHandlers,
} from '@/hooks/Mapper/types/mapHandlers.ts';
import { ForwardedRef, useImperativeHandle, useRef } from 'react';

import { OnMapSelectionChange } from '@/hooks/Mapper/components/map/map.types.ts';
import {
  useCenterSystem,
  useCommandsCharacters,
  useCommandsConnections,
  useMapAddSystems,
  useMapCommands,
  useMapInit,
  useMapRemoveSystems,
  useMapUpdateSystems,
  useSelectSystems,
} from './api';

export const useMapHandlers = (ref: ForwardedRef<MapHandlers>, onSelectionChange: OnMapSelectionChange) => {
  const mapInit = useMapInit();
  const mapAddSystems = useMapAddSystems();
  const mapUpdateSystems = useMapUpdateSystems();
  const removeSystems = useMapRemoveSystems(onSelectionChange);
  const centerSystem = useCenterSystem();
  const selectSystems = useSelectSystems(onSelectionChange);

  const selectRef = useRef({ onSelectionChange });
  selectRef.current = { onSelectionChange };

  const { addConnections, removeConnections, updateConnection } = useCommandsConnections();
  const { mapUpdated, killsUpdated } = useMapCommands();
  const { charactersUpdated, presentCharacters, characterAdded, characterRemoved, characterUpdated } =
    useCommandsCharacters();

  useImperativeHandle(ref, () => {
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
            setTimeout(() => removeConnections(data as CommandRemoveConnections), 100);
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
            selectSystems({ systems: [data as string], delay: 500 });
            break;

          case Commands.selectSystems:
            selectSystems(data as CommandSelectSystems);
            break;

          case Commands.pingAdded:
          case Commands.pingCancelled:
          case Commands.routes:
          case Commands.signaturesUpdated:
          case Commands.linkSignatureToSystem:
          case Commands.detailedKillsUpdated:
          case Commands.characterActivityData:
          case Commands.trackingCharactersData:
          case Commands.updateActivity:
          case Commands.updateTracking:
          case Commands.userSettingsUpdated:
            // do nothing
            break;

          default:
            console.warn(`Map handlers: Unknown command: ${type}`, data);
            break;
        }
      },
    };
  }, []);
};
