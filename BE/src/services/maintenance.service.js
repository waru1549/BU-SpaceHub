import { randomUUID } from 'node:crypto';
import { AppError } from '../middleware/error.middleware.js';
import { ROLES } from '../middleware/role.middleware.js';
import * as repo from '../repositories/maintenance.repository.js';
import { buildMeta, parseFilters, parsePagination } from '../utils/pagination.js';
import { toPositiveInt, toText } from '../utils/validate.js';

const CREATE_ERRORS = {
  INVALID_TITLE: [400, 'หัวข้อต้องยาว 3-255 ตัวอักษร'],
  DESCRIPTION_REQUIRED: [400, 'กรุณาอธิบายอาการอย่างน้อย 10 ตัวอักษร'],
  TARGET_REQUIRED: [400, 'กรุณาเลือกทรัพยากรหรือระบุสถานที่'],
  INVALID_LOCATION: [400, 'สถานที่ต้องไม่เกิน 255 ตัวอักษร'],
  RESOURCE_NOT_FOUND: [404, 'ไม่พบทรัพยากรที่เลือก'],
  ALREADY_REPORTED: [409, 'คุณแจ้งซ่อมทรัพยากรนี้ไว้แล้วและยังไม่ปิดงาน'],
  USER_LIMIT_REACHED: [409, 'มีงานแจ้งซ่อมที่ยังไม่ปิดครบ 5 รายการแล้ว'],
};

const CHANGE_ERRORS = {
  BOOKING_NOT_FOUND: [404, 'ไม่พบงานแจ้งซ่อมนี้'],
  FORBIDDEN: [403, 'คุณไม่มีสิทธิ์ทำรายการนี้'],
  INVALID_TRANSITION: [409, 'สถานะปัจจุบันไม่รองรับการทำรายการนี้'],
  NOT_ASSIGNED: [409, 'ยังไม่ได้มอบหมายผู้รับผิดชอบ กรุณาให้ Admin มอบหมายก่อน'],
  NOT_ASSIGNEE: [403, 'เฉพาะผู้รับผิดชอบงานหรือ Admin เท่านั้น'],
  NOTE_REQUIRED: [400, 'กรุณาระบุบันทึก/เหตุผลอย่างน้อย 3 ตัวอักษร'],
  ASSIGNEE_INVALID: [400, 'ผู้รับมอบหมายต้องเป็น Staff/Admin ที่ใช้งานอยู่'],
  INVALID_ACTION: [400, 'การดำเนินการไม่ถูกต้อง'],
  TOO_MANY_ATTACHMENTS: [409, 'แนบรูปได้ไม่เกิน 3 รูป'],
};

const translate = (error, map) => {
  const hit = map[error?.message];
  if (hit) throw new AppError(hit[1], hit[0]);
  throw new AppError('Database operation failed', 500, error);
};

const STATUSES = ['PENDING', 'APPROVED', 'IN_PROGRESS', 'COMPLETED', 'REJECTED', 'CANCELLED'];
const OPEN = ['PENDING', 'APPROVED'];
const MAX_FILES = 3;
const MAX_BYTES = 5 * 1024 * 1024;
const MIME_EXT = { 'image/jpeg': 'jpg', 'image/png': 'png', 'image/webp': 'webp' };

const LIST = {
  view: 'v_maintenance_requests',
  tieBreaker: 'booking_id',
  defaultSort: 'reported_date',
  defaultOrder: 'desc',
  sortable: ['reported_date', 'booking_code', 'repair_title', 'booking_status', 'assignee_name'],
  filters: ['booking_status', 'assigned_to'],
};

const isStaff = (user) => user.role === ROLES.STAFF || user.role === ROLES.ADMIN;
const isAdmin = (user) => user.role === ROLES.ADMIN;

const actorId = (user) => {
  const id = Number(user?.userId);
  if (!Number.isInteger(id) || id < 1) throw new AppError('Invalid session user', 500);
  return id;
};

// ctx = { staff, admin, owner, me }
export const allowedActions = (row, { staff, admin, owner, me }) => {
  const status = row.booking_status;
  const assignee = row.assigned_to != null && Number(row.assigned_to) === Number(me);
  const actions = [];
  if (OPEN.includes(status)) {
    if (owner) actions.push('CANCEL');
    if (staff) actions.push('REJECT');
    if (admin) actions.push('ASSIGN');
    if (staff && row.assigned_to != null && (admin || assignee)) actions.push('START');
  }
  if (status === 'IN_PROGRESS') {
    if (admin) actions.push('ASSIGN');
    if (staff && (admin || assignee)) actions.push('COMPLETE');
  }
  return actions;
};

const withActions = (row, ctx) => ({ ...row, actions: allowedActions(row, ctx) });

const ctxFor = (user, row) => ({
  staff: isStaff(user),
  admin: isAdmin(user),
  owner: row.user_id === actorId(user),
  me: actorId(user),
});

export const listResources = () => repo.listResources();
export const listAssignableStaff = () => repo.listAssignableStaff();

export const createRequest = async (user, body) => {
  let resourceId = null;
  if (body?.resource_id !== undefined && body?.resource_id !== null && body?.resource_id !== '') {
    resourceId = toPositiveInt(body.resource_id, 'resource_id');
  }
  const location = typeof body?.location === 'string' ? body.location.trim() : '';
  if (resourceId === null && location === '') {
    throw new AppError('กรุณาเลือกทรัพยากรหรือระบุสถานที่', 400);
  }
  const title = toText(body?.title, 'title', { min: 3, max: 255 });
  const description = toText(body?.description, 'description', { min: 10, max: 2000 });
  const { data, error } = await repo.createRequest(
    actorId(user), resourceId, location === '' ? null : location, title, description,
  );
  if (error) translate(error, CREATE_ERRORS);
  const row = await repo.getRequestById(data[0].new_booking_id);
  return withActions(row, ctxFor(user, row));
};

const resolveAssignedFilter = (filters, user) => {
  if (filters.assigned_to === undefined) return filters;
  const value = filters.assigned_to === 'me' ? actorId(user) : toPositiveInt(filters.assigned_to, 'assigned_to');
  return { ...filters, assigned_to: value };
};

const list = async (user, query, extra) => {
  const paging = parsePagination(query, LIST);
  let filters = parseFilters(query, LIST.filters);
  if (filters.booking_status && !STATUSES.includes(filters.booking_status)) {
    throw new AppError('Invalid booking_status', 400, { allowed: STATUSES });
  }
  filters = resolveAssignedFilter(filters, user);
  const { rows, total } = await repo.fetchPage(LIST, { ...paging, filters: { ...filters, ...extra } });
  return { rows: rows.map((r) => withActions(r, ctxFor(user, r))), meta: buildMeta({ total, ...paging }) };
};

export const getMyRequests = (user, query) => list(user, query, { user_id: actorId(user) });
export const getAllRequests = (user, query) => list(user, query, {});

const loadVisible = async (user, rawId) => {
  const id = toPositiveInt(rawId, 'id');
  const row = await repo.getRequestById(id);
  if (!row) throw new AppError('ไม่พบงานแจ้งซ่อมนี้', 404);
  if (!isStaff(user) && row.user_id !== actorId(user)) throw new AppError('คุณไม่มีสิทธิ์ดูงานนี้', 403);
  return row;
};

const withSignedUrls = async (rows) =>
  Promise.all(rows.map(async (a) => ({
    attachment_id: a.attachment_id,
    file_name: a.file_name,
    upload_date: a.upload_date,
    url: await repo.createSignedRead(a.file_path),
  })));

export const getRequest = async (user, rawId) => {
  const row = await loadVisible(user, rawId);
  const attachments = await withSignedUrls(await repo.listAttachments(row.booking_id));
  return { ...withActions(row, ctxFor(user, row)), attachments };
};

export const assign = async (user, rawId, body) => {
  const bookingId = toPositiveInt(rawId, 'id');
  const assigneeId = toPositiveInt(body?.assignee_id, 'assignee_id');
  const { error } = await repo.assignRequest(bookingId, assigneeId, isAdmin(user));
  if (error) translate(error, CHANGE_ERRORS);
  const row = await repo.getRequestById(bookingId);
  return withActions(row, ctxFor(user, row));
};

export const changeStatus = async (user, rawId, action, body) => {
  const bookingId = toPositiveInt(rawId, 'id');
  const note = typeof body?.note === 'string' ? body.note.trim().slice(0, 1000) : null;
  const { data, error } = await repo.changeStatus(
    bookingId, action, actorId(user), isStaff(user), isAdmin(user), note,
  );
  if (error) translate(error, CHANGE_ERRORS);
  return { booking_id: data[0].out_booking_id, status: data[0].out_status };
};

// ---------- รูปแนบ: FE อัปโหลดตรงไป Storage ด้วย signed upload URL แล้วเรียก confirm ----------
const canAttach = (user, row) => row.user_id === actorId(user) && OPEN.includes(row.booking_status);

export const signUploads = async (user, rawId, body) => {
  const row = await loadVisible(user, rawId);
  if (!canAttach(user, row)) throw new AppError('แนบรูปได้เฉพาะผู้แจ้งก่อนเริ่มซ่อม', 403);
  const files = Array.isArray(body?.files) ? body.files : [];
  if (files.length < 1) throw new AppError('กรุณาระบุไฟล์ที่ต้องการอัปโหลด', 400);
  const existing = Number(row.attachment_count) || 0;
  if (existing + files.length > MAX_FILES) {
    throw new AppError(`แนบรูปได้ไม่เกิน ${MAX_FILES} รูป (แนบแล้ว ${existing} รูป)`, 409);
  }
  const out = [];
  for (const f of files) {
    const ext = MIME_EXT[f?.content_type];
    if (!ext) throw new AppError('รองรับเฉพาะไฟล์ JPG, PNG, WebP', 400);
    const size = Number(f?.size);
    if (!Number.isFinite(size) || size <= 0 || size > MAX_BYTES) {
      throw new AppError('ขนาดไฟล์ต้องไม่เกิน 5MB', 400);
    }
    const path = `${row.booking_id}/${randomUUID()}.${ext}`;
    const { data, error } = await repo.createSignedUpload(path);
    if (error) throw new AppError('Storage error', 500, error);
    out.push({
      path,
      token: data.token,
      file_name: typeof f?.file_name === 'string' ? f.file_name.slice(0, 255) : `image.${ext}`,
    });
  }
  return out;
};

export const confirmUploads = async (user, rawId, body) => {
  const row = await loadVisible(user, rawId);
  if (!canAttach(user, row)) throw new AppError('แนบรูปได้เฉพาะผู้แจ้งก่อนเริ่มซ่อม', 403);
  const files = Array.isArray(body?.files) ? body.files : [];
  if (files.length < 1) throw new AppError('ไม่มีไฟล์ที่ต้องบันทึก', 400);
  const prefix = `${row.booking_id}/`;
  const names = await repo.listStoredNames(String(row.booking_id));
  const rows = files.map((f) => {
    const path = typeof f?.path === 'string' ? f.path : '';
    const name = path.slice(prefix.length);
    if (!path.startsWith(prefix) || !/^[0-9a-f-]{36}\.(jpg|png|webp)$/.test(name) || !names.has(name)) {
      throw new AppError('ไม่พบไฟล์ที่อัปโหลด กรุณาลองใหม่', 400);
    }
    return {
      booking_id: row.booking_id,
      file_name: typeof f?.file_name === 'string' ? f.file_name.slice(0, 255) : name,
      file_path: path,
    };
  });
  const { data, error } = await repo.insertAttachments(rows);
  if (error) {
    await repo.removeStored(rows.map((r) => r.file_path));
    translate(error, CHANGE_ERRORS);
  }
  return data;
};

export const deleteAttachment = async (user, rawId, rawAttachmentId) => {
  const row = await loadVisible(user, rawId);
  if (!canAttach(user, row)) throw new AppError('ลบรูปได้เฉพาะผู้แจ้งก่อนเริ่มซ่อม', 403);
  const att = await repo.getAttachment(toPositiveInt(rawAttachmentId, 'attachmentId'));
  if (!att || att.booking_id !== row.booking_id) throw new AppError('ไม่พบรูปนี้', 404);
  await repo.removeStored([att.file_path]);
  await repo.deleteAttachmentRow(att.attachment_id);
  return { attachment_id: att.attachment_id };
};
