import { useMapRootState } from '@/hooks/Mapper/mapRootProvider';
import { useCallback, useRef } from 'react';
import { CommandRoutes } from '@/hooks/Mapper/types';
import { RoutesList, Route } from '@/hooks/Mapper/types/routes.ts';

export const sortRoutes = (routes: Route[]): Route[] => {
  return routes.sort((a, b) => {
    if (a.origin !== b.origin) {
      return a.origin - b.origin;
    }
    return a.destination - b.destination;
  });
};

export const areIntegerArraysEqual = (arr1?: number[], arr2?: number[]): boolean => {
  if (arr1 === undefined || arr2 === undefined) {
    return arr1 === arr2;
  }
  // Sort both arrays
  const sortedArr1 = [...arr1].sort((a, b) => a - b);
  const sortedArr2 = [...arr2].sort((a, b) => a - b);

  // Check if sorted arrays have the same length
  if (sortedArr1.length !== sortedArr2.length) {
    return false;
  }

  // Check if all elements in the sorted arrays are equal
  for (let i = 0; i < sortedArr1.length; i++) {
    if (sortedArr1[i] !== sortedArr2[i]) {
      return false;
    }
  }

  return true;
};

export const areRoutesEqual = (route1: Route, route2: Route): boolean => {
  return (
    route1.origin === route2.origin &&
    route1.destination === route2.destination &&
    route1.has_connection === route2.has_connection &&
    areIntegerArraysEqual(route1.systems, route2.systems) &&
    route1.success === route2.success
  );
};

// Function to compare two RoutesList objects
export const areRoutesListsEqual = (list1?: RoutesList, list2?: RoutesList): boolean => {
  if (list1 === undefined || list2 === undefined) {
    return list1 === list2;
  }
  // First, compare the solar_system_id
  if (list1.solar_system_id !== list2.solar_system_id) {
    return false;
  }

  // Sort the routes in each list
  const sortedRoutes1 = sortRoutes(list1.routes);
  const sortedRoutes2 = sortRoutes(list2.routes);

  // Compare the sorted routes arrays
  if (sortedRoutes1.length !== sortedRoutes2.length) {
    return false;
  }

  for (let i = 0; i < sortedRoutes1.length; i++) {
    if (!areRoutesEqual(sortedRoutes1[i], sortedRoutes2[i])) {
      return false;
    }
  }

  return true;
};

export const useRoutes = () => {
  const {
    update,
    data: { routes },
  } = useMapRootState();

  const ref = useRef({ update, routes });
  ref.current = { update, routes };

  return useCallback((value: CommandRoutes) => {
    const { update, routes } = ref.current;

    if (areRoutesListsEqual(routes, value)) {
      return;
    }

    update({ routes: value });
  }, []);
};

export const useUserRoutes = () => {
  const {
    update,
    data: { userRoutes },
  } = useMapRootState();

  const ref = useRef({ update, userRoutes });
  ref.current = { update, userRoutes };

  return useCallback((value: CommandRoutes) => {
    const { update, userRoutes } = ref.current;

    if (areRoutesListsEqual(userRoutes, value)) {
      return;
    }

    update({ userRoutes: value });
  }, []);
};
