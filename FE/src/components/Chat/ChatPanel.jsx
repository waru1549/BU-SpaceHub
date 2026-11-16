import { useEffect, useRef, useState } from 'react';
import { Bot, Send, Trash2 } from 'lucide-react';
import RichText from './RichText.jsx';
import EvidencePanel from './EvidencePanel.jsx';
import { MAX_QUESTION } from '../../hooks/useChat.js';
import { useAsync } from '../../hooks/useAsync.js';
import { getSuggestions } from '../../services/chat.service.js';

const FALLBACK_SUGGESTIONS = [
  'ตอนนี้มีห้องไหนว่างบ้าง',
  'ยืมอุปกรณ์ได้กี่วัน',
  'ห้องไหนถูกจองมากที่สุด',
];

const focusRing = 'focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-indigo-600';

function Bubble({ message, onRetry }) {
  if (message.role === 'user') {
    return (
      <li className="flex justify-end">
        <p className="max-w-[85%] rounded-2xl rounded-br-md bg-indigo-700 px-4 py-2.5 text-sm wrap-break-word whitespace-pre-wrap text-white">
          {message.content}
        </p>
      </li>
    );
  }
  return (
    <li className="flex items-start gap-2">
      <span aria-hidden="true" className="mt-1 grid h-8 w-8 shrink-0 place-items-center rounded-full bg-indigo-100 text-indigo-700">
        <Bot className="h-4 w-4" />
      </span>
      <div className="min-w-0 max-w-[88%]">
        <div
          className={`rounded-2xl rounded-tl-md border px-4 py-2.5 ${
            message.error ? 'border-red-200 bg-red-50 text-red-800' : 'border-slate-200 bg-white text-slate-800'
          }`}
        >
          {message.error ? <p className="text-sm">{message.content}</p> : <RichText content={message.content} />}
          {message.error && message.question && (
            <button
              type="button"
              onClick={() => onRetry(message.id)}
              className={`mt-2 rounded-lg border border-red-300 bg-white px-3 py-1 text-xs font-medium hover:bg-red-100 ${focusRing}`}
            >
              ลองอีกครั้ง
            </button>
          )}
        </div>
        {!message.error && <EvidencePanel evidence={message.evidence} />}
      </div>
    </li>
  );
}

// แผงแชต (ใช้ทั้งหน้า /chat และปุ่มลอย) | chat = ผลจาก useChat()
export default function ChatPanel({ chat, autoFocus = false }) {
  const { messages, loading, send, retry, reset } = chat;
  const [text, setText] = useState('');
  const endRef = useRef(null);
  const inputRef = useRef(null);
  const suggestions = useAsync(getSuggestions);
  const examples = suggestions.data?.length ? suggestions.data : FALLBACK_SUGGESTIONS;

  useEffect(() => {
    endRef.current?.scrollIntoView({ block: 'end' });
  }, [messages, loading]);
  useEffect(() => {
    if (autoFocus) inputRef.current?.focus();
  }, [autoFocus]);

  const over = text.length > MAX_QUESTION;
  const submit = () => {
    if (!text.trim() || over || loading) return;
    send(text);
    setText('');
  };
  const onKeyDown = (e) => {
    if (e.key === 'Enter' && !e.shiftKey && !e.nativeEvent.isComposing) {
      e.preventDefault();
      submit();
    }
  };

  return (
    <div className="flex h-full min-h-0 flex-col">
      <div className="flex-1 overflow-y-auto px-4 py-4" tabIndex={-1}>
        {messages.length === 0 ? (
          <div className="space-y-4">
            <div className="flex items-start gap-2">
              <span aria-hidden="true" className="grid h-8 w-8 shrink-0 place-items-center rounded-full bg-indigo-100 text-indigo-700">
                <Bot className="h-4 w-4" />
              </span>
              <p className="rounded-2xl rounded-tl-md border border-slate-200 bg-white px-4 py-2.5 text-sm text-slate-800">
                สวัสดีครับ ผมน้องสเปซ ผู้ช่วย AI ของ BU SpaceHub ถามเรื่องห้อง เครื่องพิมพ์ 3D อุปกรณ์ที่ว่าง สถิติการใช้งาน
                สถานะงานแจ้งซ่อมภาพรวม หรือกฎการใช้งานได้เลยครับ (ผมอ่านข้อมูลสรุปได้อย่างเดียว และไม่แสดงข้อมูลส่วนบุคคล)
              </p>
            </div>
            <div>
              <p className="mb-2 text-xs font-medium text-slate-600">ลองถามได้เลย</p>
              <ul className="flex flex-wrap gap-2">
                {examples.map((q) => (
                  <li key={q}>
                    <button
                      type="button"
                      onClick={() => send(q)}
                      disabled={loading}
                      className={`rounded-full border border-indigo-200 bg-indigo-50 px-3 py-1.5 text-left text-xs font-medium text-indigo-900 hover:bg-indigo-100 disabled:opacity-60 ${focusRing}`}
                    >
                      {q}
                    </button>
                  </li>
                ))}
              </ul>
            </div>
          </div>
        ) : (
          <ul role="log" aria-live="polite" aria-relevant="additions" aria-label="บทสนทนากับผู้ช่วย AI" className="space-y-4">
            {messages.map((m) => (
              <Bubble key={m.id} message={m} onRetry={retry} />
            ))}
          </ul>
        )}
        {loading && (
          <p role="status" className="mt-4 flex items-center gap-2 text-xs text-slate-600">
            <span aria-hidden="true" className="inline-block h-2 w-2 animate-pulse rounded-full bg-indigo-600 motion-reduce:animate-none" />
            กำลังค้นข้อมูลและเรียบเรียงคำตอบ…
          </p>
        )}
        <div ref={endRef} />
      </div>

      <form
        onSubmit={(e) => {
          e.preventDefault();
          submit();
        }}
        className="border-t border-slate-200 bg-white p-3"
      >
        <label htmlFor="chat-input" className="sr-only">
          พิมพ์คำถามถึงผู้ช่วย AI
        </label>
        <div className="flex items-end gap-2">
          <textarea
            id="chat-input"
            ref={inputRef}
            rows={2}
            value={text}
            onChange={(e) => setText(e.target.value)}
            onKeyDown={onKeyDown}
            placeholder="พิมพ์คำถาม แล้วกด Enter เพื่อส่ง"
            aria-describedby="chat-counter"
            aria-invalid={over}
            className={`min-h-12 flex-1 resize-none rounded-xl border bg-white px-3 py-2 text-sm text-slate-900 placeholder:text-slate-500 ${
              over ? 'border-red-400' : 'border-slate-300'
            } ${focusRing}`}
          />
          <button
            type="submit"
            disabled={!text.trim() || over || loading}
            aria-label="ส่งข้อความ"
            className={`grid h-11 w-11 shrink-0 place-items-center rounded-xl bg-indigo-700 text-white hover:bg-indigo-800 disabled:cursor-not-allowed disabled:opacity-50 ${focusRing}`}
          >
            <Send className="h-5 w-5" aria-hidden="true" />
          </button>
        </div>
        <div className="mt-1.5 flex items-center justify-between text-xs">
          <span id="chat-counter" className={over ? 'font-medium text-red-700' : 'text-slate-600'}>
            {text.length}/{MAX_QUESTION}
            {over && ' · ยาวเกินกำหนด'}
          </span>
          {messages.length > 0 && (
            <button
              type="button"
              onClick={reset}
              className={`inline-flex items-center gap-1 rounded-md px-2 py-1 text-slate-700 hover:bg-slate-100 ${focusRing}`}
            >
              <Trash2 className="h-3.5 w-3.5" aria-hidden="true" />
              เริ่มบทสนทนาใหม่
            </button>
          )}
        </div>
      </form>
    </div>
  );
}
