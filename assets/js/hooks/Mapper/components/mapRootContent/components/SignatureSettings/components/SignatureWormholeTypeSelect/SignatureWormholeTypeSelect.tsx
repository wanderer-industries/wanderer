import { Dropdown } from 'primereact/dropdown';
import clsx from 'clsx';
import { Respawn, SolarSystemStaticInfoRaw, WormholeDataRaw } from '@/hooks/Mapper/types';
import { Controller, useFormContext } from 'react-hook-form';
import { useMapRootState } from '@/hooks/Mapper/mapRootProvider';
import { useSystemsSettingsProvider } from '@/hooks/Mapper/components/mapRootContent/components/SignatureSettings/Provider.tsx';
import { useSystemInfo } from '@/hooks/Mapper/components/hooks';
import {
  SOLAR_SYSTEM_CLASSES_TO_CLASS_GROUPS,
  WORMHOLES_ADDITIONAL_INFO_BY_CLASS_ID,
} from '@/hooks/Mapper/components/map/constants.ts';
import { useMemo } from 'react';
import { WHClassView } from '@/hooks/Mapper/components/ui-kit';

const getPossibleWormholes = (systemStatic: SolarSystemStaticInfoRaw, wormholes: WormholeDataRaw[]) => {
  const { id: whType } = WORMHOLES_ADDITIONAL_INFO_BY_CLASS_ID[systemStatic.system_class];

  // @ts-ignore
  const spawnClassGroup = SOLAR_SYSTEM_CLASSES_TO_CLASS_GROUPS[whType];
  const possibleWHTypes = wormholes.filter(x => {
    return x.src.some(x => {
      const [group, type] = x.split('-');

      if (type === 'shattered') {
        return systemStatic.is_shattered && group === spawnClassGroup;
      }

      return group === spawnClassGroup;
    });
  });

  return {
    statics: possibleWHTypes
      .filter(x => x.respawn.some(y => y === Respawn.static))
      .filter(x => systemStatic.statics.includes(x.name)),
    k162: wormholes.find(x => x.name === 'K162')!,
    wanderings: possibleWHTypes.filter(x => x.respawn.some(y => y === Respawn.wandering)),
  };
};

// @ts-ignore
const renderWHTypeGroupTemplate = option => {
  return (
    <div className="flex gap-2 items-center">
      <span>{option.label}</span>
    </div>
  );
};

// @ts-ignore
const renderWHTypeTemplateValue = (option: { label: string; data: WormholeDataRaw }) => {
  if (!option) {
    return 'Select wormhole type';
  }

  return (
    <div className="flex gap-2 items-center">
      <WHClassView whClassName={option.data.name} noOffset useShortTitle />
    </div>
  );
};

// @ts-ignore
const renderWHTypeTemplate = (option: { label: string; data: WormholeDataRaw }) => {
  return (
    <div className="flex gap-2 items-center ml-[1rem]">
      <WHClassView whClassName={option.data.name} noOffset useShortTitle />
    </div>
  );
};

export interface SignatureGroupSelectProps {
  name: string;
  defaultValue?: string;
}

export const SignatureWormholeTypeSelect = ({ name, defaultValue = '' }: SignatureGroupSelectProps) => {
  const { control } = useFormContext();

  const {
    data: { wormholes },
  } = useMapRootState();

  const {
    value: { systemId },
  } = useSystemsSettingsProvider();

  const system = useSystemInfo({ systemId });

  const possibleWormholesOptions = useMemo(() => {
    const possibleWormholes = getPossibleWormholes(system.staticInfo, wormholes);

    return [
      {
        label: 'Statics',
        items: [
          ...possibleWormholes.statics.map(x => ({
            label: x.name,
            value: x.name,
            data: x,
          })),
          {
            value: possibleWormholes.k162.name,
            label: possibleWormholes.k162.name,
            data: possibleWormholes.k162,
          },
        ],
      },
      {
        label: 'Wanderings',
        items: possibleWormholes.wanderings.map(x => ({
          label: x.name,
          value: x.name,
          data: x,
        })),
      },
    ];
  }, [system, wormholes]);

  return (
    <Controller
      name={name}
      control={control}
      defaultValue={defaultValue}
      render={({ field }) => (
        <Dropdown
          value={field.value}
          onChange={field.onChange}
          options={possibleWormholesOptions}
          optionLabel="label"
          optionValue="value"
          placeholder="Select wormhole type"
          optionGroupLabel="label"
          optionGroupChildren="items"
          className={clsx('w-full')}
          scrollHeight="240px"
          optionGroupTemplate={renderWHTypeGroupTemplate}
          itemTemplate={renderWHTypeTemplate}
          valueTemplate={renderWHTypeTemplateValue}
        />
      )}
    />
  );
};
