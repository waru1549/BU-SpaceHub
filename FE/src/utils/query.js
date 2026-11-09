// แปลง params ของตารางเป็น query string (ข้ามตัวกรองที่ว่าง)
export const buildListQuery = ({ page, limit, sort, order, filters = {} }) => {
  const qs = new URLSearchParams({ page, limit, sort, order });
  Object.entries(filters).forEach(([key, value]) => {
    if (value) qs.set(key, value);
  });
  return qs.toString();
};