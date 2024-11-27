import { Dropdown } from 'primereact/dropdown';
import clsx from 'clsx';
import { Controller, useFormContext } from 'react-hook-form';
import { useSystemsSettingsProvider } from '@/hooks/Mapper/components/mapRootContent/components/SignatureSettings/Provider.tsx';
import { useSystemInfo } from '@/hooks/Mapper/components/hooks';
import { useMemo } from 'react';
import { SystemView } from '@/hooks/Mapper/components/ui-kit';
import classes from './SignatureLeadsToSelect.module.scss';
import { useLoadSystemStatic } from '@/hooks/Mapper/mapRootProvider/hooks/useLoadSystemStatic.ts';
import { SystemSignature } from '@/hooks/Mapper/types';
import { WORMHOLES_ADDITIONAL_INFO_BY_CLASS_ID } from '@/hooks/Mapper/components/map/constants.ts';
import { useMapRootState } from '@/hooks/Mapper/mapRootProvider';

// @ts-ignore
const renderLinkedSystemItem = (option: { value: string }) => {
  const { value } = option;
  if (value == null) {
    return <div className="flex gap-2 items-center">- Unknown -</div>;
  }

  return (
    <div className="flex gap-2 items-center">
      <SystemView systemId={value} className={classes.SystemView} />
    </div>
  );
};

// @ts-ignore
const renderLinkedSystemValue = (option: { value: string }) => {
  if (!option) {
    return 'Select Leads To system';
  }

  if (option.value == null) {
    return 'Select Leads To system';
  }

  return (
    <div className="flex gap-2 items-center">
      <SystemView systemId={option.value} className={classes.SystemView} />
    </div>
  );
};

const renderLeadsToEmpty = () => <div className="flex items-center text-[14px]">No wormhole to select</div>;

export interface SignatureLeadsToSelectProps {
  name: string;
  defaultValue?: string;
}

export const SignatureLeadsToSelect = ({ name, defaultValue = '' }: SignatureLeadsToSelectProps) => {
  const { control, watch } = useFormContext<SystemSignature>();
  const group = watch('type');

  const {
    value: { systemId },
  } = useSystemsSettingsProvider();

  const { leadsTo } = useSystemInfo({ systemId });
  const { systems: systemStatics } = useLoadSystemStatic({ systems: leadsTo });
  const {
    data: { wormholes },
  } = useMapRootState();

  const leadsToOptions = useMemo(() => {
    return [
      { value: null },

      ...leadsTo
        .filter(systemId => {
          const systemStatic = systemStatics.get(parseInt(systemId));
          const whInfo = wormholes.find(x => x.name === group);

          if (!systemStatic || !whInfo || group === 'K162') {
            return true;
          }

          const { id: whType } = WORMHOLES_ADDITIONAL_INFO_BY_CLASS_ID[systemStatic.system_class];
          return whInfo.dest === whType;
        })
        .map(x => ({ value: x })),
    ];
  }, [group, leadsTo, systemStatics, wormholes]);

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
            options={leadsToOptions}
            optionValue="value"
            placeholder="Select Leads To wormhole"
            className={clsx('w-full')}
            scrollHeight="240px"
            itemTemplate={renderLinkedSystemItem}
            valueTemplate={renderLinkedSystemValue}
            emptyMessage={renderLeadsToEmpty}
          />
        );
      }}
    />
  );
};
