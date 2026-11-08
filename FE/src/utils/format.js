const numberCache = new Map();

export const formatNumber = (value, digits = 0) => {
  if (value === null || value === undefined || value === '') return '-';
  if (!numberCache.has(digits)) {
    numberCache.set(
      digits,
      new Intl.NumberFormat('th-TH', { minimumFractionDigits: digits, maximumFractionDigits: digits }),
    );
  }
  return numberCache.get(digits).format(Number(value));
};

export const formatDate = (value) => {
  if (!value) return '-';
  const d = new Date(value);
  if (Number.isNaN(d.getTime())) return '-';
  return d.toLocaleDateString('th-TH', { day: '2-digit', month: 'short', year: 'numeric' });
};