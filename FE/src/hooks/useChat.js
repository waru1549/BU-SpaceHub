import { useCallback, useEffect, useRef, useState } from 'react';
import { askChat } from '../services/chat.service.js';

export const MAX_QUESTION = 500;
const HISTORY_LIMIT = 6;
const SESSION_KEY = 'bu-chat-session';

const uid = () => globalThis.crypto?.randomUUID?.() ?? `m-${Date.now()}-${Math.random().toString(36).slice(2, 10)}`;

const loadSession = () => {
  try {
    const saved = sessionStorage.getItem(SESSION_KEY);
    if (saved) return saved;
  } catch { /* sessionStorage ใช้ไม่ได้: ใช้ id ชั่วคราว */ }
  return uid();
};
const saveSession = (id) => {
  try { sessionStorage.setItem(SESSION_KEY, id); } catch { /* ไม่เป็นไร */ }
};

// สถานะการสนทนาทั้งหมด (ข้อความอยู่ในหน่วยความจำ ปิดแท็บแล้วหาย) | ใช้ร่วมกันได้ทั้งหน้า /chat และปุ่มลอย
export function useChat() {
  const [messages, setMessages] = useState([]);
  const [loading, setLoading] = useState(false);
  const sessionRef = useRef(null);
  const messagesRef = useRef(messages);
  const loadingRef = useRef(false);

  useEffect(() => {
    messagesRef.current = messages;
  }, [messages]);
  if (sessionRef.current === null) {
    sessionRef.current = loadSession();
    saveSession(sessionRef.current);
  }

  const send = useCallback(async (text) => {
    const question = String(text ?? '').trim();
    if (!question || question.length > MAX_QUESTION || loadingRef.current) return;

    const history = messagesRef.current
      .filter((m) => !m.error)
      .slice(-HISTORY_LIMIT)
      .map(({ role, content }) => ({ role, content }));

    loadingRef.current = true;
    setLoading(true);
    setMessages((prev) => [...prev, { id: uid(), role: 'user', content: question }]);

    try {
      const res = await askChat({ message: question, history, sessionId: sessionRef.current });
      if (res.session_id) {
        sessionRef.current = res.session_id;
        saveSession(res.session_id);
      }
      setMessages((prev) => [
        ...prev,
        { id: uid(), role: 'assistant', content: res.answer, evidence: res.evidence ?? [], refused: Boolean(res.refused) },
      ]);
    } catch (err) {
      setMessages((prev) => [
        ...prev,
        { id: uid(), role: 'assistant', error: true, question, content: err.message || 'เกิดข้อผิดพลาด กรุณาลองใหม่' },
      ]);
    } finally {
      loadingRef.current = false;
      setLoading(false);
    }
  }, []);

  // ลองถามใหม่: ลบฟองผิดพลาดและฟองคำถามก่อนหน้าออก แล้วส่งใหม่
  const retry = useCallback((id) => {
    const list = messagesRef.current;
    const idx = list.findIndex((m) => m.id === id);
    if (idx < 1 || !list[idx].question) return;
    const question = list[idx].question;
    setMessages(list.filter((_, i) => i !== idx && i !== idx - 1));
    messagesRef.current = list.filter((_, i) => i !== idx && i !== idx - 1);
    send(question);
  }, [send]);

  const reset = useCallback(() => {
    sessionRef.current = uid();
    saveSession(sessionRef.current);
    setMessages([]);
  }, []);

  return { messages, loading, send, retry, reset };
}
