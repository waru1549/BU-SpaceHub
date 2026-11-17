# BU SpaceHub (CRMS) — ระบบจัดการทรัพยากรมหาวิทยาลัย

โครงงานวิชา **AIE313 Database System (Mini Project)** — ระบบจองห้อง, จองเครื่องพิมพ์ 3 มิติ, ยืม-คืนอุปกรณ์ และแจ้งซ่อม
พร้อมแดชบอร์ดวิเคราะห์ข้อมูล, หน้าจัดการสำหรับผู้ดูแลระบบ และ **แชต AI ถามข้อมูลจากฐานข้อมูลจริงด้วยภาษาไทย/อังกฤษ**

| รายการ | ที่อยู่ |
|---|---|
| เว็บไซต์ (Vercel) | https://bu-space-hub-qz7n.vercel.app |
| API (Render) | https://bu-spacehub-api.onrender.com/api/health |
| ซอร์สโค้ด | https://github.com/waru1549/BU-SpaceHub |

> API บน Render แพ็กเกจฟรีจะหลับเมื่อไม่มีผู้ใช้ ~15 นาที ครั้งแรกหลังตื่นอาจช้า 30–60 วินาที ให้เปิด `/api/health` เพื่อปลุกก่อนใช้งาน

## 1. เทคโนโลยี

| ส่วน | เทคโนโลยี |
|---|---|
| Frontend | React 19, Vite, Tailwind CSS v4, react-router 8 (code splitting ด้วย `lazy`) |
| Backend | Node.js ≥ 20, Express 5, helmet, cors, express-rate-limit |
| ฐานข้อมูล / Auth | Supabase (PostgreSQL, Supabase Auth — Google OAuth สำหรับนักศึกษา, อีเมล+รหัสผ่านสำหรับ Staff/Admin) |
| AI Chat | Groq API (รุ่น `openai/gpt-oss-120b`) แบบ **Tool/Function Calling** ผ่านวิวแบบอ่านอย่างเดียว |
| Deploy | Vercel (FE), Render (BE) |

## 2. โครงสร้างโฟลเดอร์

```
BE/        Express API  (routes → controllers → services → repositories)
FE/        React web application
database/  SQL ทั้งหมด (crms_full_build.sql = รวมทุกอย่างในไฟล์เดียว)
  crms_complete_schema.sql   โครงสร้างตาราง
  seed_data.sql              ข้อมูลจำลอง
  views.sql                  วิวพื้นฐาน
  analysis_queries.sql       คิวรีวิเคราะห์ Q1–Q16
  migrations/                002–013 และไฟล์ทดสอบ *_test.sql
docs/      เอกสารประกอบ (ER diagram, สคริปต์ตรวจ Chat)
```

## 3. ฐานข้อมูล

- **22 ตาราง**, **28 วิว** (วิวทั้งหมดใช้ `security_invoker = true`), 23 ฟังก์ชัน PL/pgSQL
- ตารางหลักทุกตารางมีข้อมูลจำลองไม่น้อยกว่า 30 แถว เช่น `users` 35, `resources` 38, `room_bookings` 41, `printer_bookings` 34, `equipment_bookings` 53, `maintenance_bookings` 34, `fines` 30
- ตาราง `users` เป็นตารางกลางที่ทุกโมดูลอ้างอิง (`room_bookings`, `printer_bookings`, `equipment_bookings`, `maintenance_bookings`, `chat_logs`) และผูกกับ Supabase Auth ผ่าน `users.auth_user_id → auth.users(id)`
- กติกาที่ต้องเป็น atomic (จองซ้อน, เกินจำนวน, เปลี่ยนสถานะ, เปลี่ยน role) ทำใน PL/pgSQL; ฟังก์ชันถูก `REVOKE` จาก PUBLIC/anon/authenticated และ `GRANT` ให้ `service_role` เท่านั้น (BE เป็นผู้เรียก)
- ER diagram: `docs/ER_Diagram_keys.png` (เฉพาะคีย์), `docs/ER_Diagram_full.png` (ทุกคอลัมน์) ต้นฉบับ Mermaid: `docs/ER_Diagram_*.mmd`
- คิวรีวิเคราะห์ 16 ข้อ (4 กลุ่ม × 4): `database/analysis_queries.sql` (คำถามธุรกิจ → SQL → ผลลัพธ์ → การแปลความหมาย)

### สร้างฐานข้อมูลใหม่ทั้งหมด

1. สร้างโปรเจกต์ Supabase ใหม่ (หรือใช้ฐานข้อมูลที่ยอมให้ล้างได้)
2. เปิด **SQL Editor** แล้วรัน `database/crms_full_build.sql` ทั้งไฟล์
   - ⚠️ ไฟล์นี้ `DROP` และ `TRUNCATE` ข้อมูลเดิมก่อนใส่ข้อมูลจำลอง ห้ามรันบนฐานข้อมูลที่มีข้อมูลจริง
   - ไฟล์นี้คือ schema → seed → views → migrations 002–013 ต่อกันตามลำดับ (ทดสอบแล้วบนฐานข้อมูลว่างโดยไม่มี error)
3. ช่วงเวลาจองสาธิต (003, 005) นับจากวันที่รัน (14 วันข้างหน้า) ถ้าเลยช่วงนั้น ให้ Admin สร้างใหม่จากหน้า **จัดการทรัพยากร → ตารางเวลา**

### ชุดทดสอบฐานข้อมูล

รันแต่ละไฟล์ใน SQL Editor (ทุกไฟล์ `ROLLBACK` ท้ายไฟล์ ไม่ทิ้งข้อมูล) ทุกแถวในตารางผลลัพธ์ต้องเป็น `PASS`

| ไฟล์ | จำนวนข้อ | ทดสอบ |
|---|---|---|
| `migrations/008_test.sql` | 23 | แจ้งซ่อม |
| `migrations/009_test.sql` | 17 | Dashboard v2 |
| `migrations/010_test.sql` | 9 | วิวติดตามงานซ่อม |
| `migrations/011_test.sql` | 14 | AI Chat |
| `migrations/012_test.sql` | 40 | Admin จัดการทรัพยากร |
| `migrations/013_test.sql` | 17 | Admin จัดการผู้ใช้ |

## 4. ฟีเจอร์ตามบทบาท

| บทบาท | ทำอะไรได้ |
|---|---|
| ผู้เยี่ยมชม | ใช้แชต AI ถามข้อมูลสาธารณะ (ห้ามข้อมูลส่วนบุคคล) |
| USER (นักศึกษา) | จองห้อง, จองเครื่องพิมพ์ 3 มิติ, ยืมอุปกรณ์, แจ้งซ่อมและติดตามสถานะ, ดู Dashboard |
| STAFF | อนุมัติ/ปฏิเสธคำขอ, ส่งมอบ-รับคืนอุปกรณ์, ดำเนินงานซ่อม |
| ADMIN | ทุกอย่างของ STAFF + จัดการทรัพยากร (เพิ่ม/แก้/ลบ, สร้างตารางเวลาเป็นชุด, บล็อกช่วงเวลา) + จัดการผู้ใช้ (ค้นหา, เปลี่ยน role, ระงับ/เปิดบัญชี) |

กฎความปลอดภัยของบัญชี Admin: แก้ role/สถานะของตัวเองไม่ได้, ต้องเหลือ Admin ที่ใช้งานอยู่อย่างน้อย 1 คน, ระงับผู้ใช้ที่ยังมีรายการ active ไม่ได้ และผู้ใช้ที่ไม่ใช่ `ACTIVE` ถูกปฏิเสธ (403) ทุกคำขอที่ต้องล็อกอิน

### การเข้าสู่ระบบ
- นักศึกษา: Google OAuth เฉพาะอีเมล `@bumail.net` (ตั้งค่าได้ด้วย `ALLOWED_EMAIL_DOMAIN`) ระบบสร้างบัญชีให้อัตโนมัติครั้งแรก
- Staff/Admin: ต้องมีแถวในตาราง `users` ล่วงหน้า (กำหนด role) และสร้างผู้ใช้ใน Supabase Auth ด้วย **อีเมลเดียวกัน** (ยืนยันอีเมลแล้ว) ระบบจะจับคู่ด้วยอีเมลตอนล็อกอินครั้งแรก

## 5. AI Chat (เชื่อม LLM กับฐานข้อมูล)

- วิธี A: **Tool/Function Calling** — LLM เลือกเรียก Tool ที่กำหนดไว้ล่วงหน้า (ค้นกติกา, ทรัพยากร, ช่วงเวลาว่างของห้อง/เครื่องพิมพ์, สต็อกอุปกรณ์, สถิติการใช้งาน, สรุประบบ, ภาพรวมงานซ่อม, แนวโน้มรายเดือน)
- Tool อ่านได้เฉพาะวิว `v_ai_*` ที่ไม่มีข้อมูลส่วนบุคคล (ไม่มี text-to-SQL อิสระ)
- ทุกคำตอบแสดง **หลักฐาน**: ชื่อ Tool, วิวที่ใช้, SQL ที่เทียบเท่า, จำนวนแถว และตารางผลลัพธ์
- จำกัด 10 ข้อความ/นาที/IP และบันทึกลงตาราง `chat_logs` (IP ถูกแฮช)
- คิวรีวิเคราะห์ที่เลือกนำเสนอทั้งบน Dashboard และผ่าน Chat ตามข้อกำหนด: Q3 (อุปกรณ์ค้างคืน), Q10 (ทรัพยากรที่ซ่อมซ้ำ), Q12 (แนวโน้มรายเดือนแยกโมดูล)

## 6. รันบนเครื่องตัวเอง

ต้องมี Node.js ≥ 20 และโปรเจกต์ Supabase ที่สร้างฐานข้อมูลตามข้อ 3 แล้ว

```bash
# Backend (พอร์ต 5000)
cd BE
cp .env.example .env      # เติมค่าจริง (ห้าม commit)
npm install
npm run dev

# Frontend (พอร์ต 5170)
cd FE
cp .env.example .env      # เติมค่าจริง (ห้าม commit)
npm install
npm run dev
```

ตัวแปรสภาพแวดล้อม (ระบุเฉพาะชื่อ ค่าจริงอยู่ในไฟล์ `.env` ที่ถูก git-ignore)

| ไฟล์ | ตัวแปร |
|---|---|
| `BE/.env` | `PORT`, `NODE_ENV`, `FRONTEND_URL` (โดเมนที่อนุญาต CORS คั่นด้วยจุลภาค), `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`, `ALLOWED_EMAIL_DOMAIN`, `TRUST_PROXY` (ตั้ง `1` เมื่ออยู่หลัง proxy เช่น Render), `GROQ_API_KEY`, `GROQ_MODEL` |
| `FE/.env` | `VITE_API_URL`, `VITE_SUPABASE_URL`, `VITE_SUPABASE_PUBLISHABLE_KEY` |

ใน Supabase → Authentication → URL Configuration ต้องเพิ่ม Redirect URL ของโดเมนที่ใช้ (เช่น `http://localhost:5170/**` และโดเมน Vercel)

## 7. API (ภาพรวม)

คำนำหน้า `/api` — `GET /health`, `GET /health/db`

| กลุ่ม | เส้นทาง | สิทธิ์ |
|---|---|---|
| ยืนยันตัวตน | `/auth/*` | ตามเส้นทาง |
| Dashboard | `/dashboard/*` | ล็อกอิน |
| ห้อง / เครื่องพิมพ์ / อุปกรณ์ / แจ้งซ่อม | `/rooms`, `/printers`, `/equipment`, `/maintenance` | USER (จอง/ยืม/แจ้ง), STAFF/ADMIN (จัดการคำขอ) |
| AI Chat | `/chat` (`/suggestions`, `/whoami`) | สาธารณะ (ผูกผู้ใช้ถ้ามี token) |
| Admin ทรัพยากร | `/admin/resources` (+ `/options`, `/:id/schedules`, `/:id/schedules/generate`, …) | ADMIN |
| Admin ผู้ใช้ | `/admin/users` (+ `/options`, `PUT /:id/role`, `PUT /:id/status`) | ADMIN |

ข้อความ error ของกติกาธุรกิจเป็นภาษาไทย ไฟล์ตัวอย่างการเรียก API ทั้งหมดอยู่ใน `BE/http/*.http` (ใช้กับ VS Code REST Client; token ทดสอบอ่านจาก `BE/http/.env` ซึ่งไม่อยู่ใน repo)

## 8. การ Deploy

1. **Render (BE)**: Web Service, Root Directory `BE`, Build `npm install`, Start `npm start`, Health Check `/api/health`, ตั้งตัวแปรตามตารางข้อ 6 (`NODE_ENV=production`, `TRUST_PROXY=1`, `FRONTEND_URL` = โดเมน Vercel ไม่มี `/` ท้าย)
2. **Vercel (FE)**: Root Directory `FE`, Framework Vite, ตั้ง `VITE_*` ก่อน build (ไฟล์ `FE/vercel.json` ทำให้ react-router ทำงานเมื่อรีเฟรชหน้าลึก)
3. **Supabase**: ตั้ง Site URL และ Redirect URLs เป็นโดเมน Vercel

## 9. ความปลอดภัย

- ความลับ (`SUPABASE_SERVICE_ROLE_KEY`, `GROQ_API_KEY`) อยู่ในตัวแปรสภาพแวดล้อมของ Render/ไฟล์ `.env` ที่ git-ignore เท่านั้น; ฝั่งเบราว์เซอร์ใช้เฉพาะ publishable key
- ทุกเส้นทาง Admin ตรวจ token + role ฝั่ง BE; วิวและฟังก์ชันของระบบเรียกได้เฉพาะ `service_role`
- Rate limit ทั้ง API และ Chat; CORS จำกัดเฉพาะโดเมนที่กำหนด; `helmet` เปิดใช้งาน