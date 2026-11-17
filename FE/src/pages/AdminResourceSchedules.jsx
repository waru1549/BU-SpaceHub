import { useState } from 'react';
import { Link, useParams } from 'react-router';
import { ArrowLeft } from 'lucide-react';
import Notice from '../components/Feedback/Notice.jsx';
import ErrorBanner from '../components/Admin/ErrorBanner.jsx';
import ResourceStatusBadge from '../components/Admin/ResourceStatusBadge.jsx';
import ScheduleGenerator from '../components/Admin/ScheduleGenerator.jsx';
import ScheduleList from '../components/Admin/ScheduleList.jsx';
import { useAsync } from '../hooks/useAsync.js';
import { getResource } from '../services/adminResources.service.js';
import { CATEGORY_LABEL, hasSchedule } from '../utils/adminResources.js';
import { useCallback } from 'react';

const backLink =
  'inline-flex items-center gap-1 text-sm font-medium text-indigo-800 hover:underline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-indigo-600';

function Content({ id }) {
  const fetchOne = useCallback(() => getResource(id), [id]);
  const resource = useAsync(fetchOne);
  const [notice, setNotice] = useState(null);
  const [version, setVersion] = useState(0);
  const r = resource.data;

  if (resource.loading) return <div aria-hidden="true" className="h-40 animate-pulse rounded-2xl bg-slate-100 motion-reduce:animate-none" />;
  if (resource.error) {
    return (
      <ErrorBanner>
        {resource.error}{' '}
        <button type="button" onClick={resource.reload} className="font-medium underline">ลองอีกครั้ง</button>
      </ErrorBanner>
    );
  }
  if (!hasSchedule(r.category)) {
    return <ErrorBanner>ทรัพยากรหมวด "{CATEGORY_LABEL[r.category] ?? r.category}" ไม่มีตารางเวลา (ใช้เฉพาะห้องและเครื่องพิมพ์ 3D)</ErrorBanner>;
  }

  return (
    <div className="space-y-6">
      <header className="space-y-1">
        <h1 className="text-2xl font-bold text-slate-800">ตารางเวลา: {r.resource_name}</h1>
        <p className="flex flex-wrap items-center gap-2 text-sm text-slate-600">
          <span>{r.resource_code}</span>
          <span aria-hidden="true">·</span>
          <span>{CATEGORY_LABEL[r.category]}</span>
          <ResourceStatusBadge status={r.resource_status} />
        </p>
        {r.resource_status !== 'AVAILABLE' && (
          <p className="text-sm text-amber-900">ทรัพยากรนี้ไม่ได้อยู่ในสถานะพร้อมใช้งาน ผู้ใช้จะจองไม่ได้แม้มีช่วงเวลาเปิดอยู่</p>
        )}
      </header>

      {notice && <Notice type="success" onDismiss={() => setNotice(null)}>{notice}</Notice>}

      <ScheduleGenerator
        resourceId={id}
        onDone={(message) => {
          setNotice(message);
          setVersion((v) => v + 1);
        }}
      />
      <ScheduleList resourceId={id} kind={r.category} version={version} onNotice={setNotice} />
    </div>
  );
}

export default function AdminResourceSchedules() {
  const { id } = useParams();
  return (
    <div className="space-y-4">
      <Link to="/admin/resources" className={backLink}>
        <ArrowLeft className="h-4 w-4" aria-hidden="true" />
        กลับไปจัดการทรัพยากร
      </Link>
      <Content key={id} id={id} />
    </div>
  );
}
