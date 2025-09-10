const TYPE_ORDER = [
  'undefined',
  'null',
  'boolean',
  'number',
  'bigint',
  'string',
  'symbol',
  'function',
  'date',
  'regexp',
  'other',
] as const;
type TypeTag = (typeof TYPE_ORDER)[number];

const getTypeTag = (v: unknown): TypeTag => {
  if (v === undefined) return 'undefined';
  if (v === null) return 'null';
  const t = typeof v;
  if (t === 'boolean' || t === 'number' || t === 'bigint' || t === 'string' || t === 'symbol' || t === 'function')
    return t as TypeTag;
  const tag = Object.prototype.toString.call(v);
  if (tag === '[object Date]') return 'date';
  if (tag === '[object RegExp]') return 'regexp';
  return 'other';
};

const cmp = (a: unknown, b: unknown): number => {
  const ta = getTypeTag(a);
  const tb = getTypeTag(b);
  if (ta !== tb) return TYPE_ORDER.indexOf(ta) - TYPE_ORDER.indexOf(tb);

  switch (ta) {
    case 'undefined':
    case 'null':
      return 0;
    case 'boolean':
      return (a as boolean) === (b as boolean) ? 0 : a ? 1 : -1;
    case 'number': {
      const na = a as number,
        nb = b as number;
      const aIsNaN = Number.isNaN(na),
        bIsNaN = Number.isNaN(nb);
      if (aIsNaN || bIsNaN) return aIsNaN && bIsNaN ? 0 : aIsNaN ? 1 : -1; // NaN в конец чисел
      return na === nb ? 0 : na < nb ? -1 : 1;
    }
    case 'bigint': {
      const ba = a as bigint,
        bb = b as bigint;
      return ba === bb ? 0 : ba < bb ? -1 : 1;
    }
    case 'string':
      return (a as string).localeCompare(b as string);
    case 'symbol': {
      const da = (a as symbol).description ?? '';
      const db = (b as symbol).description ?? '';
      return da.localeCompare(db);
    }
    case 'function':
      // @ts-ignore
      return ((a as Function).name || '').localeCompare((b as Function).name || '');
    case 'date':
      return (a as Date).getTime() - (b as Date).getTime();
    case 'regexp':
      return a!.toString().localeCompare(b!.toString());
    default:
      return String(a).localeCompare(String(b));
  }
};

const isIterable = (v: unknown): v is Iterable<unknown> =>
  v != null && typeof (v as any)[Symbol.iterator] === 'function';

const pushTypedArrayValues = (v: unknown, out: unknown[]) => {
  if (ArrayBuffer.isView(v) && !(v instanceof DataView)) {
    // @ts-ignore
    out.push(...(v as ArrayLike<number> as any));
    return true;
  }
  return false;
};

/**
 * Generate this func with ChatGPT 5. Cause it pure func and looks like what i need
 * May be in net we can find smtng like that
 * @param input
 */
export const flattenValues = (input: unknown): unknown[] => {
  const out: unknown[] = [];
  const seen = new WeakSet<object>();

  const visit = (v: unknown): void => {
    const tag = getTypeTag(v);
    if (tag !== 'other') {
      out.push(v);
      return;
    }

    if (v && typeof v === 'object') {
      if (seen.has(v)) return;
      seen.add(v);

      if (pushTypedArrayValues(v, out)) return;

      if (v instanceof Map) {
        for (const val of v.values()) visit(val);
        return;
      }

      if (v instanceof Set) {
        for (const val of v.values()) visit(val);
        return;
      }

      if (Array.isArray(v) || isIterable(v)) {
        for (const item of v as Iterable<unknown>) visit(item);
        return;
      }

      for (const key of Object.keys(v)) {
        // @ts-ignore
        visit((v as never)[key]);
      }
      return;
    }

    out.push(v);
  };

  visit(input);
  return out.sort(cmp);
};
