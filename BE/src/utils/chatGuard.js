import { createHash, randomUUID } from 'node:crypto';

export const MAX_QUESTION = 500;
export const MAX_HISTORY = 6;

// คำถามที่ขอข้อมูลส่วนบุคคล / พยายามสั่งแหกกฎ: ปฏิเสธทันที ไม่ส่งให้ LLM
const PII_PATTERN = /(อีเมล|e-?mail|เบอร์(โทร)?|โทรศัพท์|รหัสผ่าน|password|token|secret|api[\s_-]?key|รหัสนักศึกษา|ข้อมูลส่วนตัว|ใคร(เป็นคน)?(จอง|ยืม|แจ้งซ่อม|ใช้)|ชื่อ(ผู้|คน)(จอง|ยืม|ใช้|แจ้ง|ซ่อม))/i;
const INJECTION_PATTERN = /(ignore\s+(all|any|the|previous|above)|system\s*prompt|developer\s*message|jailbreak|ละเลย(คำสั่ง|กฎ)|ไม่ต้องสนใจ(คำสั่ง|กฎ)|คำสั่ง(ก่อนหน้า|ระบบ)|เปิดเผย.{0,20}(prompt|พรอมต์|คำสั่ง)|\bDROP\s+TABLE\b|\bDELETE\s+FROM\b)/i;

export const REFUSAL_PII =
  'ขออภัยครับ ผมให้ข้อมูลส่วนบุคคลไม่ได้ (เช่น ชื่อ อีเมล เบอร์โทร หรือผู้ที่จอง/ยืม) ผมตอบได้เฉพาะข้อมูลสรุปของระบบ เช่น ห้อง/อุปกรณ์ที่ว่าง สถิติการใช้งาน สถานะงานแจ้งซ่อมภาพรวม และกฎการใช้งาน';
export const REFUSAL_INJECTION =
  'ขออภัยครับ ผมทำตามคำสั่งนั้นไม่ได้ ผมช่วยตอบเรื่องการใช้งานระบบ BU SpaceHub ได้ เช่น ห้องหรืออุปกรณ์ที่ว่าง สถิติ และกฎการใช้งาน';

export const checkRefusal = (text) => {
  if (INJECTION_PATTERN.test(text)) return REFUSAL_INJECTION;
  if (PII_PATTERN.test(text)) return REFUSAL_PII;
  return null;
};

export const hashIp = (ip) =>
  createHash('sha256').update(`${process.env.CHAT_IP_SALT || 'bu-spacehub'}:${ip || 'unknown'}`).digest('hex').slice(0, 32);

const SESSION_PATTERN = /^[A-Za-z0-9_-]{8,64}$/;
export const normalizeSessionId = (v) => (typeof v === 'string' && SESSION_PATTERN.test(v) ? v : randomUUID());

// ประวัติสนทนาจาก FE ถือเป็นข้อมูลไม่น่าเชื่อถือ: รับเฉพาะ user/assistant ข้อความสั้น ไม่เกิน MAX_HISTORY
export const sanitizeHistory = (history) =>
  (Array.isArray(history) ? history : [])
    .filter((m) => m && (m.role === 'user' || m.role === 'assistant') && typeof m.content === 'string')
    .slice(-MAX_HISTORY)
    .map((m) => ({ role: m.role, content: m.content.trim().slice(0, 1000) }))
    .filter((m) => m.content);
