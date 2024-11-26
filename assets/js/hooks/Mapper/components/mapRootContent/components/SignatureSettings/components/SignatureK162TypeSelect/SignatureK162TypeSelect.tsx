import { Dropdown } from 'primereact/dropdown';
import clsx from 'clsx';
import { Controller, useFormContext } from 'react-hook-form';
import { useMemo } from 'react';
import { SystemView } from '@/hooks/Mapper/components/ui-kit';
import classes from './SignatureK162TypeSelect.module.scss';
import { SystemSignature } from '@/hooks/Mapper/types';
import { SOLAR_SYSTEM_CLASS_IDS } from '@/hooks/Mapper/components/map/constants.ts';

const k162Types = [
  {
    label: 'Hi-Sec',
    value: 'hs',
    system_class: SOLAR_SYSTEM_CLASS_IDS.hs,
    security: '1.0',
  },
  {
    label: 'Low-Sec',
    value: 'ls',
    system_class: SOLAR_SYSTEM_CLASS_IDS.ls,
    security: '0.3',
  },
  {
    label: 'Null-Sec',
    value: 'ns',
    system_class: SOLAR_SYSTEM_CLASS_IDS.ns,
    security: '0.0',
  },
  {
    label: 'C1',
    value: 'c1',
    system_class: SOLAR_SYSTEM_CLASS_IDS.c1,
  },
  {
    label: 'C2',
    value: 'c2',
    system_class: SOLAR_SYSTEM_CLASS_IDS.c2,
  },
  {
    label: 'C3',
    value: 'c3',
    system_class: SOLAR_SYSTEM_CLASS_IDS.c3,
  },
  {
    label: 'C4',
    value: 'c4',
    system_class: SOLAR_SYSTEM_CLASS_IDS.c4,
  },
  {
    label: 'C5',
    value: 'c5',
    system_class: SOLAR_SYSTEM_CLASS_IDS.c5,
  },
  {
    label: 'C6',
    value: 'c6',
    system_class: SOLAR_SYSTEM_CLASS_IDS.c6,
  },
  {
    label: 'Thera',
    value: 'thera',
    system_class: SOLAR_SYSTEM_CLASS_IDS.thera,
  },
  {
    label: 'Pochven',
    value: 'pochven',
    system_class: SOLAR_SYSTEM_CLASS_IDS.pochven,
  },
];

import { SolarSystemStaticInfoRaw } from '@/hooks/Mapper/types';

const renderNoValue = () => <div className="flex gap-2 items-center ml-[1rem]">-Unknown-</div>;

// @ts-ignore
const renderOption = (option: { label?: string; value: string; security?: string; system_class?: number }) => {
  if (!option) {
    return renderNoValue();
  }
  const { value, label = '', system_class = 0, security = '1.0' } = option;
  if (value == null) {
    return renderNoValue();
  }

  const systemInfo: SolarSystemStaticInfoRaw = {
    region_id: 0,
    constellation_id: 0,
    solar_system_id: 0,
    constellation_name: '',
    region_name: '',
    system_class: system_class,
    security: security,
    type_description: '',
    class_title: label,
    is_shattered: false,
    effect_name: '',
    effect_power: 0,
    statics: [],
    wandering: [],
    triglavian_invasion_status: '',
    sun_type_id: 0,
    solar_system_name: '',
    solar_system_name_lc: '',
  };
  return (
    <div className="flex gap-2 items-center ml-[1rem]">
      <SystemView systemId="" className={classes.SystemView} showCustomName hideRegion systemInfo={systemInfo} />
    </div>
  );
};

export interface SignatureK162TypeSelectProps {
  name: string;
  defaultValue?: string;
}

export const SignatureK162TypeSelect = ({ name, defaultValue = '' }: SignatureK162TypeSelectProps) => {
  const { control } = useFormContext<SystemSignature>();

  const options = useMemo(() => {
    return [{ value: null }, ...k162Types];
  }, []);

  return (
    <Controller
      // @ts-ignore
      name={name}
      control={control}
      defaultValue={defaultValue}
      render={({ field }) => {
        return (
          <Dropdown
            value={field.value}
            onChange={field.onChange}
            options={options}
            optionValue="value"
            placeholder="Select Leads To wormhole"
            className={clsx('w-full')}
            scrollHeight="240px"
            itemTemplate={renderOption}
            valueTemplate={renderOption}
          />
        );
      }}
    />
  );
};
