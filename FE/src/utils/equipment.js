// กติกาการยืมที่แสดงให้ผู้ใช้เห็น (ตัวบังคับจริงอยู่ที่ DB: fn_equipment_create_booking)
export const LOAN_RULES = { maxDays: 7, maxAheadDays: 14, maxActive: 2, dueHour: '16:00' };

const TZ = 'Asia/Bangkok';

export const formatDay = (iso) =>
  iso
    ? new Date(iso).toLocaleDateString('th-TH', { day: 'numeric', month: 'short', year: 'numeric', timeZone: TZ })
    : '-';

export const formatDayTime = (iso) => {
  if (!iso) return '-';
  const time = new Date(iso).toLocaleTimeString('th-TH', {
    hour: '2-digit',
    minute: '2-digit',
    hour12: false,
    timeZone: TZ,
  });
  return `${formatDay(iso)} ${time} น.`;
};

export const formatBaht = (amount) =>
  `${Number(amount ?? 0).toLocaleString('th-TH', { minimumFractionDigits: 0, maximumFractionDigits: 2 })} บาท`;

export const FINE_AMOUNT_MAX = 100000;

// ปุ่มและข้อความของแต่ละการดำเนินการ (รหัสตรงกับฟิลด์ actions ที่ BE ส่งมา)
export const EQUIPMENT_ACTIONS = {
  APPROVE: {
    path: 'approve',
    button: 'อนุมัติ',
    title: 'อนุมัติคำขอยืม',
    question: 'ต้องการอนุมัติคำขอยืมนี้ใช่หรือไม่',
    confirm: 'ยืนยันการอนุมัติ',
    busy: 'กำลังอนุมัติ…',
    done: 'อนุมัติคำขอยืม',
    trigger: 'border-emerald-300 text-emerald-800 hover:bg-emerald-50',
    solid: 'bg-emerald-700 hover:bg-emerald-800',
  },
  REJECT: {
    path: 'reject',
    button: 'ปฏิเสธ',
    title: 'ปฏิเสธคำขอยืม',
    question: 'ต้องการปฏิเสธคำขอยืมนี้ใช่หรือไม่ ผู้ยืมต้องขอใหม่หากยังต้องการใช้อุปกรณ์',
    confirm: 'ยืนยันการปฏิเสธ',
    busy: 'กำลังปฏิเสธ…',
    done: 'ปฏิเสธคำขอยืม',
    trigger: 'border-red-300 text-red-800 hover:bg-red-50',
    solid: 'bg-red-700 hover:bg-red-800',
  },
  CANCEL: {
    path: 'cancel',
    button: 'ยกเลิก',
    title: 'ยกเลิกคำขอยืม',
    question: 'ต้องการยกเลิกคำขอยืมนี้ใช่หรือไม่ อุปกรณ์จะกลับมาให้ผู้อื่นยืมได้',
    confirm: 'ยืนยันการยกเลิก',
    busy: 'กำลังยกเลิก…',
    done: 'ยกเลิกคำขอยืม',
    trigger: 'border-red-300 text-red-800 hover:bg-red-50',
    solid: 'bg-red-700 hover:bg-red-800',
  },
  RECEIVE: {
    path: 'receive',
    button: 'ส่งมอบ',
    title: 'ส่งมอบอุปกรณ์',
    question: 'ยืนยันว่าส่งมอบอุปกรณ์ให้ผู้ยืมแล้วใช่หรือไม่ (ตรวจสภาพอุปกรณ์ก่อนส่งมอบ)',
    confirm: 'ยืนยันส่งมอบ',
    busy: 'กำลังบันทึก…',
    done: 'ส่งมอบอุปกรณ์',
    trigger: 'border-amber-500 text-amber-900 hover:bg-amber-50',
    solid: 'bg-amber-700 hover:bg-amber-800',
  },
  RETURN: {
    path: 'return',
    button: 'รับคืน',
    title: 'รับคืนอุปกรณ์',
    question: 'ตรวจสภาพอุปกรณ์แล้วยืนยันการรับคืน หากชำรุดหรือสูญหายให้ระบุยอดค่าปรับ (การคืนล่าช้าไม่คิดค่าปรับ)',
    confirm: 'ยืนยันรับคืน',
    busy: 'กำลังบันทึก…',
    done: 'รับคืนอุปกรณ์',
    trigger: 'border-amber-500 text-amber-900 hover:bg-amber-50',
    solid: 'bg-amber-700 hover:bg-amber-800',
  },
};
