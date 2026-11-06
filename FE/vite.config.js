import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
import tailwindcss from '@tailwindcss/vite';

export default defineConfig({
  plugins: [react(), tailwindcss()],
  // strictPort: ถ้า 5174 ถูกใช้อยู่ให้ error แทนที่จะสลับพอร์ตเอง (กัน OAuth redirect พัง)
  server: { port: 5174, strictPort: true },
  preview: { port: 5174, strictPort: true },
});