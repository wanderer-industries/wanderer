import m_interface from './interface';
import killsWidget from './killsWidget';
import localWidget from './localWidget';
import onTheMap from './onTheMap';
import routes from './routes';
import signaturesWidget from './signaturesWidget';
import widgets from './widgets';
export * from './applyMigrations.ts';

export const migrations = [
  ...m_interface,
  ...killsWidget,
  ...localWidget,
  ...onTheMap,
  ...routes,
  ...signaturesWidget,
  ...widgets,
];
