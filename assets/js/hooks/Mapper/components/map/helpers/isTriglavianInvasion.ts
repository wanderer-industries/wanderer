export const isTriglavianInvasion = (triglavianInvasionStatus: string) => {
  switch (triglavianInvasionStatus) {
    case 'Normal':
      return false;
    case 'Final':
    case 'Edencom':
    case 'Triglavian':
      return true;
  }
};
