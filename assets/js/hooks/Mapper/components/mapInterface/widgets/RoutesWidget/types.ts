import { RoutesType } from '@/hooks/Mapper/mapRootProvider/types.ts';
import { RoutesList } from '@/hooks/Mapper/types/routes.ts';

export type LoadRoutesCommand = (systemId: string, routesSettings: RoutesType) => Promise<void>;
export type AddHubCommand = (systemId: string) => Promise<void>;
export type ToggleHubCommand = (systemId: string) => Promise<void>;

export type RoutesWidgetProps = {
  data: RoutesType;
  update: (d: RoutesType) => void;
  hubs: string[];
  routesList: RoutesList | undefined;
  loading: boolean;

  addHubCommand: AddHubCommand;
  toggleHubCommand: ToggleHubCommand;
  isRestricted?: boolean;
};

export type RoutesProviderInnerProps = RoutesWidgetProps;

export type RoutesImperativeHandle = {
  stopLoading: () => void;
};
