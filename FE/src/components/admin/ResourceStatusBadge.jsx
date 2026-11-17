import { RESOURCE_STATUS_LABEL, RESOURCE_STATUS_STYLE } from '../../utils/adminResources.js';

export default function ResourceStatusBadge({ status }) {
  return (
    <span
      className={`inline-block whitespace-nowrap rounded-full px-2.5 py-1 text-xs font-semibold ${
        RESOURCE_STATUS_STYLE[status] ?? 'bg-slate-100 text-slate-800'
      }`}
    >
      {RESOURCE_STATUS_LABEL[status] ?? status}
    </span>
  );
}
