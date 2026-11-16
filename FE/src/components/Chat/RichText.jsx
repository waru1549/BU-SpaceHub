import { parseBlocks, parseInline } from '../../utils/richText.js';

function Inline({ text }) {
  return parseInline(text).map((p, i) =>
    p.type === 'strong' ? <strong key={i} className="font-semibold">{p.text}</strong> : <span key={i}>{p.text}</span>,
  );
}

export default function RichText({ content }) {
  return (
    <div className="space-y-2 text-sm leading-relaxed">
      {parseBlocks(content).map((b, i) => {
        if (b.type === 'ul' || b.type === 'ol') {
          const Tag = b.type;
          return (
            <Tag key={i} className={`space-y-1 pl-5 ${b.type === 'ul' ? 'list-disc' : 'list-decimal'}`}>
              {b.items.map((it, j) => <li key={j}><Inline text={it} /></li>)}
            </Tag>
          );
        }
        if (b.type === 'table') {
          return (
            <div key={i} className="overflow-x-auto rounded-lg border border-slate-200">
              <table className="min-w-full text-left text-xs">
                {b.header && (
                  <thead className="bg-slate-100 text-slate-700">
                    <tr>{b.header.map((h, j) => <th key={j} scope="col" className="px-2 py-1.5 font-semibold"><Inline text={h} /></th>)}</tr>
                  </thead>
                )}
                <tbody className="divide-y divide-slate-100">
                  {b.rows.map((r, j) => (
                    <tr key={j}>{r.map((c, k) => <td key={k} className="px-2 py-1.5"><Inline text={c} /></td>)}</tr>
                  ))}
                </tbody>
              </table>
            </div>
          );
        }
        if (b.type === 'heading') return <p key={i} className="font-semibold"><Inline text={b.text} /></p>;
        return <p key={i} className="whitespace-pre-wrap"><Inline text={b.text} /></p>;
      })}
    </div>
  );
}
