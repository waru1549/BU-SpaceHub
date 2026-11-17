import { ROLE_LABEL, ROLE_STYLE, USER_STATUS_LABEL, USER_STATUS_STYLE } from '../../utils/adminUsers.js';

const base = 'inline-block whitespace-nowrap rounded-full px-2.5 py-1 text-xs font-semibold';

export function RoleBadge({ role }) {
  return <span className={`${base} ${ROLE_STYLE[role] ?? 'bg-slate-100 text-slate-800'}`}>{ROLE_LABEL[role] ?? role}</span>;
}

export function UserStatusBadge({ status }) {
  return (
    <span className={`${base} ${USER_STATUS_STYLE[status] ?? 'bg-slate-100 text-slate-800'}`}>
      {USER_STATUS_LABEL[status] ?? status}
    </span>
  );
}
