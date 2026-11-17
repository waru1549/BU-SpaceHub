import { useEffect, useState } from 'react';
import Modal from '../Modals/Modal.jsx';
import { createResource, updateResource } from '../../services/adminResources.service.js';
import { CATEGORY_LABEL, RESOURCE_STATUS_LABEL, SYSTEM_STATUSES, validateResource } from '../../utils/adminResources.js';

const focusRing = 'focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-indigo-600';
const fieldClass = (bad) =>
  `w-full rounded-lg border bg-white px-3 py-2 text-sm text-slate-900 disabled:bg-slate-100 disabled:text-slate-700 ${
    bad ? 'border-red-400' : 'border-slate-300'
  } ${focusRing}`;
const btnSecondary = `rounded-lg border border-slate-300 px-4 py-2 text-sm font-medium text-slate-700 hover:bg-slate-100 disabled:opacity-50 ${focusRing}`;
const btnPrimary = `rounded-lg bg-indigo-700 px-4 py-2 text-sm font-medium text-white hover:bg-indigo-800 disabled:opacity-60 ${focusRing}`;

const EMPTY = {
  resource_code: '', resource_name: '', type_id: '', location: '',
  capacity: '', quantity: '', description: '', status: 'AVAILABLE',
};

const fromRow = (row) => ({
  resource_code: row.resource_code ?? '',
  resource_name: row.resource_name ?? '',
  type_id: String(row.type_id),
  location: row.location ?? '',
  capacity: row.capacity == null ? '' : String(row.capacity),
  quantity: row.quantity == null ? '' : String(row.quantity),
  description: row.description ?? '',
  status: row.resource_status,
});

function Field({ id, label, error, hint, required, children }) {
  return (
    <div>
      <label htmlFor={id} className="mb-1 block text-xs font-semibold text-slate-700">
        {label}
        {required && <span aria-hidden="true" className="text-red-700"> *</span>}
      </label>
      {children}
      {hint && !error && <p id={`${id}-hint`} className="mt-1 text-xs text-slate-600">{hint}</p>}
      {error && <p id={`${id}-err`} role="alert" className="mt-1 text-xs text-red-800">{error}</p>}
    </div>
  );
}

// target = null | { mode: 'create' } | { mode: 'edit', row } | options = { categories, settable_statuses }
export default function ResourceFormModal({ target, options, onClose, onSaved }) {
  const [values, setValues] = useState(EMPTY);
  const [errors, setErrors] = useState({});
  const [serverError, setServerError] = useState(null);
  const [busy, setBusy] = useState(false);

  const isEdit = target?.mode === 'edit';
  const row = target?.row;

  useEffect(() => {
    if (!target) return;
    setValues(isEdit ? fromRow(row) : EMPTY);
    setErrors({});
    setServerError(null);
  }, [target]); // eslint-disable-line react-hooks/exhaustive-deps

  const category = isEdit
    ? row.category
    : options?.categories?.find((c) => String(c.type_id) === values.type_id)?.type_name ?? null;
  const showCapacity = category === 'ROOM' || (isEdit && row.capacity != null);
  const showQuantity = category === 'EQUIPMENT' || (isEdit && row.quantity != null);

  const set = (key) => (e) => setValues((v) => ({ ...v, [key]: e.target.value }));

  const settable = options?.settable_statuses ?? ['AVAILABLE', 'BROKEN', 'UNDER_MAINTENANCE', 'OUT_OF_SERVICE'];
  const statusChoices = SYSTEM_STATUSES.includes(values.status) ? [values.status, ...settable] : settable;

  const submit = async () => {
    const found = validateResource(values, {
      category, isEdit, needCapacity: category === 'ROOM', needQuantity: category === 'EQUIPMENT',
    });
    setErrors(found);
    if (Object.keys(found).length > 0) return;

    const toNum = (s) => (String(s).trim() === '' ? null : Number(s));
    const body = {
      resource_code: values.resource_code.trim(),
      resource_name: values.resource_name.trim(),
      location: values.location.trim() || null,
      capacity: showCapacity ? toNum(values.capacity) : null,
      quantity: showQuantity ? toNum(values.quantity) : null,
      description: values.description.trim() || null,
      status: values.status,
    };

    setBusy(true);
    setServerError(null);
    try {
      const saved = isEdit
        ? await updateResource(row.resource_id, body)
        : await createResource({ ...body, type_id: Number(values.type_id) });
      onSaved(isEdit ? `บันทึกการแก้ไข ${saved.resource_code} แล้ว` : `เพิ่ม ${saved.resource_code} เรียบร้อยแล้ว`, saved);
    } catch (err) {
      if (err.status === 409) setErrors({ resource_code: err.message });
      else setServerError(err.message);
    } finally {
      setBusy(false);
    }
  };

  const close = () => {
    if (!busy) onClose();
  };

  return (
    <Modal
      open={target !== null}
      title={isEdit ? `แก้ไขทรัพยากร ${row?.resource_code ?? ''}` : 'เพิ่มทรัพยากรใหม่'}
      onClose={close}
      busy={busy}
      footer={
        <>
          <button type="button" onClick={close} disabled={busy} className={btnSecondary}>
            ยกเลิก
          </button>
          <button type="button" onClick={submit} disabled={busy} className={btnPrimary}>
            {busy ? 'กำลังบันทึก…' : isEdit ? 'บันทึกการแก้ไข' : 'เพิ่มทรัพยากร'}
          </button>
        </>
      }
    >
      <form
        onSubmit={(e) => {
          e.preventDefault();
          submit();
        }}
        noValidate
        className="space-y-4 text-sm"
      >
        {!isEdit && (
          <Field id="rs-type" label="หมวดหมู่" required error={errors.type_id} hint="เลือกแล้วเปลี่ยนภายหลังไม่ได้">
            <select
              id="rs-type"
              name="type_id"
              value={values.type_id}
              onChange={set('type_id')}
              aria-invalid={Boolean(errors.type_id)}
              className={fieldClass(errors.type_id)}
              data-autofocus
            >
              <option value="">— เลือกหมวดหมู่ —</option>
              {(options?.categories ?? []).map((c) => (
                <option key={c.type_id} value={c.type_id}>
                  {CATEGORY_LABEL[c.type_name] ?? c.type_name}
                </option>
              ))}
            </select>
          </Field>
        )}
        {isEdit && (
          <p className="text-slate-700">
            หมวดหมู่: <span className="font-semibold text-slate-900">{CATEGORY_LABEL[category] ?? category}</span>{' '}
            <span className="text-xs text-slate-600">(เปลี่ยนไม่ได้)</span>
          </p>
        )}

        <Field id="rs-code" label="รหัสทรัพยากร" required error={errors.resource_code} hint="เช่น RM-A101 (A-Z ตัวเลข _ -)">
          <input
            id="rs-code"
            name="resource_code"
            value={values.resource_code}
            onChange={set('resource_code')}
            maxLength={50}
            autoComplete="off"
            aria-invalid={Boolean(errors.resource_code)}
            className={fieldClass(errors.resource_code)}
            data-autofocus={isEdit ? true : undefined}
          />
        </Field>
        <Field id="rs-name" label="ชื่อ" required error={errors.resource_name}>
          <input
            id="rs-name"
            name="resource_name"
            value={values.resource_name}
            onChange={set('resource_name')}
            maxLength={255}
            aria-invalid={Boolean(errors.resource_name)}
            className={fieldClass(errors.resource_name)}
          />
        </Field>
        <Field id="rs-location" label="สถานที่" error={errors.location}>
          <input
            id="rs-location"
            name="location"
            value={values.location}
            onChange={set('location')}
            maxLength={255}
            aria-invalid={Boolean(errors.location)}
            className={fieldClass(errors.location)}
          />
        </Field>

        {(showCapacity || showQuantity) && (
          <div className="grid gap-4 sm:grid-cols-2">
            {showCapacity && (
              <Field id="rs-capacity" label="ความจุ (ที่นั่ง)" required={category === 'ROOM'} error={errors.capacity}>
                <input
                  id="rs-capacity"
                  name="capacity"
                  type="number"
                  inputMode="numeric"
                  min={1}
                  max={1000}
                  value={values.capacity}
                  onChange={set('capacity')}
                  aria-invalid={Boolean(errors.capacity)}
                  className={fieldClass(errors.capacity)}
                />
              </Field>
            )}
            {showQuantity && (
              <Field id="rs-quantity" label="จำนวนทั้งหมด" required={category === 'EQUIPMENT'} error={errors.quantity}>
                <input
                  id="rs-quantity"
                  name="quantity"
                  type="number"
                  inputMode="numeric"
                  min={1}
                  max={10000}
                  value={values.quantity}
                  onChange={set('quantity')}
                  aria-invalid={Boolean(errors.quantity)}
                  className={fieldClass(errors.quantity)}
                />
              </Field>
            )}
          </div>
        )}

        <Field id="rs-status" label="สถานะ" hint="สถานะ จองแล้ว/ถูกยืม ระบบจัดการให้เอง ตั้งเองไม่ได้">
          <select id="rs-status" name="status" value={values.status} onChange={set('status')} className={fieldClass(false)}>
            {statusChoices.map((s) => (
              <option key={s} value={s}>
                {RESOURCE_STATUS_LABEL[s] ?? s}
                {SYSTEM_STATUSES.includes(s) ? ' (ระบบจัดการ)' : ''}
              </option>
            ))}
          </select>
        </Field>
        <Field id="rs-desc" label="คำอธิบาย" error={errors.description}>
          <textarea
            id="rs-desc"
            name="description"
            rows={3}
            value={values.description}
            onChange={set('description')}
            maxLength={2000}
            aria-invalid={Boolean(errors.description)}
            className={fieldClass(errors.description)}
          />
        </Field>

        {serverError && (
          <p role="alert" className="rounded-lg border border-red-200 bg-red-50 px-3 py-2 text-xs text-red-800">
            {serverError}
          </p>
        )}
        <button type="submit" className="hidden" tabIndex={-1} aria-hidden="true" />
      </form>
    </Modal>
  );
}
