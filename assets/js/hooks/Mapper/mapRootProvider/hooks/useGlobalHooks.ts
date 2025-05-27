import { useLoadPublicRoutes } from './useLoadPublicRoutes';

/* TODO this hook needs for call some actions which should affect all mapper*/
export const useGlobalHooks = () => {
  useLoadPublicRoutes();
};
