// กติกาแจ้งซ่อมที่แสดงให้ผู้ใช้เห็น (ตัวบังคับจริงอยู่ที่ DB/BE)
export const MAINTENANCE_BUCKET = 'maintenance-images';
export const MAX_IMAGES = 3;
export const MAX_IMAGE_BYTES = 5 * 1024 * 1024;
export const IMAGE_TYPES = ['image/jpeg', 'image/png', 'image/webp'];
export const IMAGE_ACCEPT = IMAGE_TYPES.join(',');
export const TITLE_MAX = 255;
export const DESCRIPTION_MIN = 10;
export const DESCRIPTION_MAX = 2000;

export const formatFileSize = (bytes) =>
  bytes >= 1024 * 1024 ? `${(bytes / 1024 / 1024).toFixed(1)} MB` : `${Math.max(1, Math.round(bytes / 1024))} KB`;

// ตรวจไฟล์รูปก่อนอัปโหลด คืนข้อความผิดพลาดหรือ null
export const validateImage = (file) => {
  if (!IMAGE_TYPES.includes(file.type)) return `${file.name}: รองรับเฉพาะไฟล์ JPG, PNG, WebP`;
  if (file.size > MAX_IMAGE_BYTES) return `${file.name}: ขนาดเกิน 5MB (${formatFileSize(file.size)})`;
  return null;
};

export const ROLE_LABEL = { STAFF: 'เจ้าหน้าที่', ADMIN: 'แอดมิน' };

// ปุ่มและข้อความของแต่ละการดำเนินการ (รหัสตรงกับฟิลด์ actions ที่ BE ส่งมา)
// note: 'required' = ต้องกรอก (>= 3 ตัวอักษร) | null = ไม่มีช่องบันทึก
export const MAINTENANCE_ACTIONS = {
  ASSIGN: {
    button: 'มอบหมาย',
    title: 'มอบหมายผู้รับผิดชอบ',
    question: 'เลือก Staff ที่จะรับผิดชอบงานซ่อมนี้ (เฉพาะผู้ที่ได้รับมอบหมายหรือแอดมินเท่านั้นที่เริ่มซ่อมและปิดงานได้)',
    confirm: 'ยืนยันการมอบหมาย',
    busy: 'กำลังบันทึก…',
    done: 'มอบหมายงาน',
    note: null,
    trigger: 'border-sky-300 text-sky-800 hover:bg-sky-50',
    solid: 'bg-sky-700 hover:bg-sky-800',
  },
  START: {
    path: 'start',
    button: 'เริ่มซ่อม',
    title: 'เริ่มดำเนินการซ่อม',
    question: 'ต้องการเริ่มซ่อมงานนี้ใช่หรือไม่ ทรัพยากรที่เกี่ยวข้องจะถูกตั้งเป็น "ปิดซ่อมบำรุง" จนกว่าจะปิดงาน',
    confirm: 'ยืนยันเริ่มซ่อม',
    busy: 'กำลังบันทึก…',
    done: 'เริ่มซ่อม',
    note: null,
    trigger: 'border-sky-500 text-sky-900 hover:bg-sky-50',
    solid: 'bg-sky-700 hover:bg-sky-800',
  },
  COMPLETE: {
    path: 'complete',
    button: 'ปิดงาน',
    title: 'ปิดงานซ่อม',
    question: 'บันทึกผลการซ่อมก่อนปิดงาน ทรัพยากรที่เกี่ยวข้องจะกลับมาใช้งานได้',
    confirm: 'ยืนยันปิดงาน',
    busy: 'กำลังบันทึก…',
    done: 'ปิดงานซ่อม',
    note: 'required',
    noteLabel: 'บันทึกผลการซ่อม',
    notePlaceholder: 'เช่น เปลี่ยนหลอดไฟและทดสอบแล้ว',
    trigger: 'border-emerald-300 text-emerald-800 hover:bg-emerald-50',
    solid: 'bg-emerald-700 hover:bg-emerald-800',
  },
  REJECT: {
    path: 'reject',
    button: 'ปฏิเสธ',
    title: 'ปฏิเสธงานแจ้งซ่อม',
    question: 'ระบุเหตุผลที่ไม่รับเรื่อง ผู้แจ้งจะเห็นเหตุผลนี้',
    confirm: 'ยืนยันการปฏิเสธ',
    busy: 'กำลังปฏิเสธ…',
    done: 'ปฏิเสธงานแจ้งซ่อม',
    note: 'required',
    noteLabel: 'เหตุผล',
    notePlaceholder: 'เช่น ไม่ใช่ความรับผิดชอบของระบบ',
    trigger: 'border-red-300 text-red-800 hover:bg-red-50',
    solid: 'bg-red-700 hover:bg-red-800',
  },
  CANCEL: {
    path: 'cancel',
    button: 'ยกเลิก',
    title: 'ยกเลิกงานแจ้งซ่อม',
    question: 'ต้องการยกเลิกงานแจ้งซ่อมนี้ใช่หรือไม่ (ยกเลิกได้ก่อนเริ่มซ่อมเท่านั้น)',
    confirm: 'ยืนยันการยกเลิก',
    busy: 'กำลังยกเลิก…',
    done: 'ยกเลิกงานแจ้งซ่อม',
    note: null,
    trigger: 'border-red-300 text-red-800 hover:bg-red-50',
    solid: 'bg-red-700 hover:bg-red-800',
  },
};
