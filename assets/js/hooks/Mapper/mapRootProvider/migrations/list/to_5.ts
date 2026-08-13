import { MigrationStructure } from '@/hooks/Mapper/mapRootProvider/types.ts';

export const to_5: MigrationStructure = {
  to: 5,
  up: (prev: any) => {
    const interfaceSettings = prev?.interface || {};

    return {
      ...prev,
      interface: {
        ...interfaceSettings,
        //if this is right sould fix "unidentified" parameter pushed to default value of "false" for previously set interfacesetting ?? or am i geting this wrong ? RFC...
        show_animated_border: interfaceSettings.show_animated_border ?? false,
        show_animated_outline: interfaceSettings.show_animated_outline ?? false,
        disable_animated_outlineborder: interfaceSettings.disable_animated_outlineborder ?? false,
      },
    };
  },
};
