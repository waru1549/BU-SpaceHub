import { useEffect, useMemo, useRef, useState } from 'react';
import { ImagePlus, X } from 'lucide-react';
import { IMAGE_ACCEPT, formatFileSize, validateImage } from '../../utils/maintenance.js';

const focusRing =
  'focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-sky-600';

// เลือกรูปแนบ (สูงสุด max รูป) พร้อมตัวอย่างและปุ่มลบ | files: File[] ควบคุมจากภายนอก
export default function ImagePicker({ files, onChange, max, disabled = false, id = 'image-picker' }) {
  const inputRef = useRef(null);
  const [error, setError] = useState(null);

  const previews = useMemo(() => files.map((f) => ({ file: f, url: URL.createObjectURL(f) })), [files]);
  useEffect(() => () => previews.forEach((p) => URL.revokeObjectURL(p.url)), [previews]);

  const onPick = (e) => {
    const picked = Array.from(e.target.files ?? []);
    e.target.value = '';
    if (picked.length === 0) return;
    for (const f of picked) {
      const problem = validateImage(f);
      if (problem) {
        setError(problem);
        return;
      }
    }
    if (files.length + picked.length > max) {
      setError(`แนบรูปได้อีก ${Math.max(0, max - files.length)} รูป (สูงสุด 3 รูปต่อเรื่อง)`);
      return;
    }
    setError(null);
    onChange([...files, ...picked]);
  };

  const remove = (index) => {
    setError(null);
    onChange(files.filter((_, i) => i !== index));
  };

  return (
    <div className="space-y-2">
      <div className="flex flex-wrap items-center gap-3">
        <input
          ref={inputRef}
          id={id}
          name="images"
          type="file"
          accept={IMAGE_ACCEPT}
          multiple
          onChange={onPick}
          disabled={disabled || files.length >= max}
          className="sr-only"
        />
        <button
          type="button"
          onClick={() => inputRef.current?.click()}
          disabled={disabled || files.length >= max}
          className={`inline-flex items-center gap-2 rounded-lg border border-sky-300 bg-white px-3 py-2 text-sm font-medium text-sky-900 hover:bg-sky-50 disabled:opacity-50 ${focusRing}`}
        >
          <ImagePlus className="h-4 w-4" aria-hidden="true" />
          เลือกรูป
        </button>
        <span className="text-xs text-slate-600">
          เลือกแล้ว {files.length}/{max} รูป · JPG, PNG, WebP ไม่เกิน 5MB ต่อรูป
        </span>
      </div>

      {error && (
        <p role="alert" className="rounded-lg border border-red-200 bg-red-50 px-3 py-2 text-sm text-red-900">
          {error}
        </p>
      )}

      {previews.length > 0 && (
        <ul className="grid grid-cols-3 gap-2">
          {previews.map((p, i) => (
            <li key={p.url} className="relative overflow-hidden rounded-lg border border-slate-200 bg-slate-50">
              <img src={p.url} alt={`ตัวอย่างรูป ${p.file.name}`} className="h-24 w-full object-cover" />
              <p className="truncate px-1.5 py-1 text-xs text-slate-700">
                {p.file.name} ({formatFileSize(p.file.size)})
              </p>
              <button
                type="button"
                onClick={() => remove(i)}
                disabled={disabled}
                aria-label={`ลบรูป ${p.file.name}`}
                className={`absolute right-1 top-1 rounded-full bg-white/90 p-1 text-slate-800 shadow hover:bg-white ${focusRing}`}
              >
                <X className="h-3.5 w-3.5" aria-hidden="true" />
              </button>
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}
