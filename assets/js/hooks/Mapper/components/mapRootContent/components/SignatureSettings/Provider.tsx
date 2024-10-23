import { createGenericContext } from '@/hooks/Mapper/utils/abstractContextProvider.tsx';

export interface SystemsSettingsProvider {
  systemId: string;
}

const { Provider, useContextValue } = createGenericContext<SystemsSettingsProvider>();

export const SystemsSettingsProvider = Provider;
export const useSystemsSettingsProvider = useContextValue;
