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

export const formatBaht = (value) =>
  value === null || value === undefined || value === '' ? '-' : `฿${formatNumber(value, 2)}`;

// "2026-11" -> "พ.ย. 2569"
export const formatMonth = (label) => {
  const [y, m] = String(label).split('-').map(Number);
  if (!y || !m) return String(label);
  return new Date(y, m - 1, 1).toLocaleDateString('th-TH', { month: 'short', year: 'numeric' });
};

// ---- วันที่/เวลาของการจอง (วันที่เป็นข้อความ YYYY-MM-DD ไม่ผ่านเขตเวลาเครื่อง) ----

// "09:00:00" -> "09:00"
export const formatTime = (value) => (value ? String(value).slice(0, 5) : '-');

export const formatTimeRange = (start, end) => `${formatTime(start)}–${formatTime(end)} น.`;

// "2026-11-10" -> "วันอังคารที่ 10 พฤศจิกายน 2569"
export const formatDateLong = (iso) => {
  if (!iso) return '-';
  const d = new Date(`${iso}T00:00:00Z`);
  if (Number.isNaN(d.getTime())) return '-';
  return d.toLocaleDateString('th-TH', {
    weekday: 'long',
    day: 'numeric',
    month: 'long',
    year: 'numeric',
    timeZone: 'UTC',
  });
};

// วันนี้ตามเขตเวลาไทย รูปแบบ YYYY-MM-DD
export const todayIso = () => new Date().toLocaleDateString('sv-SE', { timeZone: 'Asia/Bangkok' });

export const addDaysIso = (iso, days) => {
  const d = new Date(`${iso}T00:00:00Z`);
  d.setUTCDate(d.getUTCDate() + days);
  return d.toISOString().slice(0, 10);
};