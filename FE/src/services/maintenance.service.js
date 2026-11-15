import { api } from './api.js';
import { supabase } from './supabase.js';
import { buildListQuery } from '../utils/query.js';
import { MAINTENANCE_BUCKET } from '../utils/maintenance.js';

export const getResources = async () => (await api.get('/maintenance/resources')).data;
export const getAssignableStaff = async () => (await api.get('/maintenance/staff')).data;

export const createRequest = async ({ resourceId, location, title, description }) =>
  (
    await api.post('/maintenance/requests', {
      resource_id: resourceId || undefined,
      location: location || undefined,
      title,
      description,
    })
  ).data;

export const getMyRequests = async (params) => {
  const json = await api.get(`/maintenance/requests/mine?${buildListQuery(params)}`);
  return { rows: json.data, meta: json.meta };
};

export const getAllRequests = async (params) => {
  const json = await api.get(`/maintenance/requests?${buildListQuery(params)}`);
  return { rows: json.data, meta: json.meta };
};

export const getRequest = async (id) => (await api.get(`/maintenance/requests/${id}`)).data;

export const assignRequest = async (id, assigneeId) =>
  (await api.post(`/maintenance/requests/${id}/assign`, { assignee_id: assigneeId })).data;

// action path: 'start' | 'complete' | 'reject' | 'cancel' ; note ใช้กับ complete/reject
export const changeRequestStatus = async (id, path, note) =>
  (await api.post(`/maintenance/requests/${id}/${path}`, note ? { note } : undefined)).data;

export const deleteAttachment = async (id, attachmentId) =>
  (await api.delete(`/maintenance/requests/${id}/attachments/${attachmentId}`)).data;

// อัปโหลดรูป: ขอ signed URL จาก BE -> อัปโหลดตรงไป Storage -> แจ้ง BE ให้บันทึก
export const uploadImages = async (id, files) => {
  const signed = (
    await api.post(`/maintenance/requests/${id}/attachments/sign`, {
      files: files.map((f) => ({ file_name: f.name, content_type: f.type, size: f.size })),
    })
  ).data;

  for (let i = 0; i < files.length; i += 1) {
    const { error } = await supabase.storage
      .from(MAINTENANCE_BUCKET)
      .uploadToSignedUrl(signed[i].path, signed[i].token, files[i], { contentType: files[i].type });
    if (error) throw new Error(`อัปโหลด ${files[i].name} ไม่สำเร็จ: ${error.message}`);
  }

  return (
    await api.post(`/maintenance/requests/${id}/attachments`, {
      files: signed.map((s) => ({ path: s.path, file_name: s.file_name })),
    })
  ).data;
};
