export type FormatVariable = {
  id: string;
  desc: string;
};

export const FORMAT_VARIABLES: FormatVariable[] = [
  { id: '{index}', desc: 'Numeric index (e.g., 1, 2, 3)' },
  { id: '{index_letter}', desc: 'Letter index (e.g., A, B, C)' },
  { id: '{chain_index}', desc: 'Numeric chain path (e.g., 11, 12, 121)' },
  { id: '{chain_index_letters}', desc: 'Letter chain path (e.g., A, A1, A21)' },
  { id: '{sig_letters}', desc: 'First 3 chars of signature (e.g., ABC)' },
  { id: '{sig}', desc: 'Full signature ID (e.g., ABC-123)' },
  { id: '{dest_type}', desc: 'Destination class (e.g., C5, HS, Thera)' },
  {
    id: '{dest_class_index}',
    desc: 'Letter index for multiple holes to same class (empty if only 1, otherwise a, b, c...)',
  },
  { id: '{type}', desc: 'Wormhole type (e.g., K162, H900)' },
  { id: '{size}', desc: 'Hole size (e.g., S, M, XL)' },
  { id: '{mass}', desc: 'Total mass in bil (e.g., 3.3)' },
  { id: '{time_status}', desc: 'Time remaining (e.g., 1H, 4H, 16H)' },
  { id: '{mass_status}', desc: 'Mass remaining (e.g., Destab, Crit)' },
  { id: '{temporary_name}', desc: 'Temporary name if set' },
  { id: '{description}', desc: 'Custom description' },
];
