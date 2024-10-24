import { createEvent } from 'react-event-hook';

import { Command, CommandData } from '@/hooks/Mapper/types/mapHandlers.ts';

export interface MapEvent<T extends Command> {
  name: T;
  data: CommandData[T];
}

const { useMapEventListener, emitMapEvent } = createEvent('map-event')<MapEvent<Command>>();

export { useMapEventListener, emitMapEvent };
