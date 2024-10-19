import { createEvent } from 'react-event-hook';

export interface MapEvent {
  name: string;
  data: {
    solar_system_source: number;
    solar_system_target: number;
  };
}

const { useMapEventListener, emitMapEvent } = createEvent('map-event')<MapEvent>();

export { useMapEventListener, emitMapEvent };
