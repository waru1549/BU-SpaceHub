// ค่าคงที่และตัวช่วยของหน้า Admin จัดการผู้ใช้

export const ROLE_LABEL = { USER: 'นักศึกษา', STAFF: 'เจ้าหน้าที่', ADMIN: 'ผู้ดูแลระบบ' };

export const ROLE_STYLE = {
  USER: 'bg-slate-100 text-slate-800',
  STAFF: 'bg-sky-100 text-sky-900',
  ADMIN: 'bg-indigo-100 text-indigo-900',
};

export const USER_STATUS_LABEL = { ACTIVE: 'ใช้งานอยู่', INACTIVE: 'ปิดบัญชี', SUSPENDED: 'ถูกระงับ' };

// ข้อความสถานะแสดงเสมอ ไม่พึ่งสีอย่างเดียว
export const USER_STATUS_STYLE = {
  ACTIVE: 'bg-emerald-100 text-emerald-900',
  INACTIVE: 'bg-slate-200 text-slate-800',
  SUSPENDED: 'bg-red-100 text-red-900',
};

export const ROLE_FILTER = [
  ['', 'ทุกบทบาท'],
  ['USER', 'นักศึกษา'],
  ['STAFF', 'เจ้าหน้าที่'],
  ['ADMIN', 'ผู้ดูแลระบบ'],
];

export const STATUS_FILTER = [
  ['', 'ทุกสถานะ'],
  ['ACTIVE', 'ใช้งานอยู่'],
  ['SUSPENDED', 'ถูกระงับ'],
  ['INACTIVE', 'ปิดบัญชี'],
];

export const ROLE_HINT = {
  USER: 'จอง/ยืม/แจ้งซ่อมของตัวเองได้',
  STAFF: 'อนุมัติและจัดการคำขอของผู้ใช้ได้',
  ADMIN: 'จัดการทรัพยากรและผู้ใช้ได้ทั้งหมด',
};

export const formatDateTime = (iso) => {
  if (!iso) return 'ยังไม่เคยเข้าสู่ระบบ';
  const d = new Date(iso);
  if (Number.isNaN(d.getTime())) return '-';
  return d.toLocaleString('th-TH', {
    timeZone: 'Asia/Bangkok', day: 'numeric', month: 'short', year: 'numeric', hour: '2-digit', minute: '2-digit',
  });
};
