// วัสดุที่ BE รองรับ (ต้องตรงกับ MATERIALS ใน BE printers.service.js)
export const MATERIAL_OPTIONS = [
  ['PLA', 'PLA'],
  ['PETG', 'PETG'],
  ['ABS', 'ABS'],
  ['ASA', 'ASA'],
  ['TPU', 'TPU (ยืดหยุ่น)'],
  ['NYLON', 'ไนลอน'],
  ['RESIN', 'เรซิน'],
  ['OTHER', 'อื่นๆ'],
];

export const MATERIAL_LABEL = Object.fromEntries(MATERIAL_OPTIONS);

export const WEIGHT_MAX = 5000;

export const formatWeight = (grams) =>
  grams === null || grams === undefined ? '-' : `${Number(grams)} ก.`;

// ปุ่มและข้อความของแต่ละการดำเนินการ (รหัสตรงกับฟิลด์ actions ที่ BE ส่งมา)
export const PRINTER_ACTIONS = {
  APPROVE: {
    path: 'approve',
    button: 'อนุมัติ',
    title: 'อนุมัติการจอง',
    question: 'ต้องการอนุมัติการจองนี้ใช่หรือไม่',
    confirm: 'ยืนยันการอนุมัติ',
    busy: 'กำลังอนุมัติ…',
    done: 'อนุมัติการจอง',
    trigger: 'border-emerald-300 text-emerald-800 hover:bg-emerald-50',
    solid: 'bg-emerald-700 hover:bg-emerald-800',
  },
  REJECT: {
    path: 'reject',
    button: 'ปฏิเสธ',
    title: 'ปฏิเสธการจอง',
    question: 'ต้องการปฏิเสธการจองนี้ใช่หรือไม่ ผู้จองต้องจองใหม่หากยังต้องการใช้เครื่อง',
    confirm: 'ยืนยันการปฏิเสธ',
    busy: 'กำลังปฏิเสธ…',
    done: 'ปฏิเสธการจอง',
    trigger: 'border-red-300 text-red-800 hover:bg-red-50',
    solid: 'bg-red-700 hover:bg-red-800',
  },
  CANCEL: {
    path: 'cancel',
    button: 'ยกเลิก',
    title: 'ยกเลิกการจอง',
    question: 'ต้องการยกเลิกการจองนี้ใช่หรือไม่ ช่วงเวลานี้จะกลับมาเปิดให้จองอีกครั้ง',
    confirm: 'ยืนยันการยกเลิก',
    busy: 'กำลังยกเลิก…',
    done: 'ยกเลิกการจอง',
    trigger: 'border-red-300 text-red-800 hover:bg-red-50',
    solid: 'bg-red-700 hover:bg-red-800',
  },
  START: {
    path: 'start',
    button: 'เริ่มพิมพ์',
    title: 'เริ่มพิมพ์งาน',
    question: 'ต้องการเริ่มพิมพ์งานนี้ใช่หรือไม่',
    confirm: 'ยืนยันเริ่มพิมพ์',
    busy: 'กำลังบันทึก…',
    done: 'เริ่มพิมพ์งาน',
    trigger: 'border-emerald-300 text-emerald-800 hover:bg-emerald-50',
    solid: 'bg-emerald-700 hover:bg-emerald-800',
  },
  COMPLETE: {
    path: 'complete',
    button: 'พิมพ์เสร็จ',
    title: 'บันทึกว่าพิมพ์เสร็จ',
    question: 'ยืนยันว่าพิมพ์งานนี้เสร็จแล้วและพร้อมให้ผู้ใช้มารับใช่หรือไม่',
    confirm: 'ยืนยันพิมพ์เสร็จ',
    busy: 'กำลังบันทึก…',
    done: 'บันทึกพิมพ์เสร็จ',
    trigger: 'border-emerald-300 text-emerald-800 hover:bg-emerald-50',
    solid: 'bg-emerald-700 hover:bg-emerald-800',
  },
  RECEIVE: {
    path: 'receive',
    button: 'รับงานแล้ว',
    title: 'ยืนยันการรับงาน',
    question: 'ยืนยันว่าคุณได้รับชิ้นงานแล้วใช่หรือไม่',
    confirm: 'ยืนยันรับงาน',
    busy: 'กำลังบันทึก…',
    done: 'ยืนยันรับงาน',
    trigger: 'border-emerald-600 text-emerald-800 hover:bg-emerald-50',
    solid: 'bg-emerald-700 hover:bg-emerald-800',
  },
};
