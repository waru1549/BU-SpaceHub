import RoomRequestsPanel from '../components/Requests/RoomRequestsPanel.jsx';

// หน้าคิวคำขอของเจ้าหน้าที่ ตอนนี้มีโมดูลห้อง; เครื่องพิมพ์ อุปกรณ์ และแจ้งซ่อมจะเพิ่มในขั้นถัดไป
export default function StaffRequests() {
  return (
    <div className="space-y-6">
      <header>
        <h1 className="text-2xl font-bold text-slate-800">คำขอรออนุมัติ</h1>
        <p className="text-sm text-slate-600">ตรวจสอบและดำเนินการกับคำขอของผู้ใช้</p>
      </header>

      <RoomRequestsPanel />
    </div>
  );
}