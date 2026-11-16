// แปลงข้อความ markdown แบบง่ายที่ LLM มักตอบ (หัวข้อ/ลิสต์/ตาราง/ตัวหนา) เป็นโครงสร้างให้ React แสดงผล
// ไม่ใช้ dangerouslySetInnerHTML: ทุกอย่างถูก render เป็น text node

const BULLET = /^\s*[-*•]\s+(.*)$/;
const ORDERED = /^\s*\d+[.)]\s+(.*)$/;
const TABLE_ROW = /^\s*\|.*\|\s*$/;
const TABLE_SEP = /^\s*\|?[\s:|-]+\|[\s:|-]*$/;

export const parseInline = (text) =>
  String(text)
    .split(/(\*\*[^*]+\*\*)/g)
    .filter(Boolean)
    .map((part) =>
      part.startsWith('**') && part.endsWith('**') && part.length > 4
        ? { type: 'strong', text: part.slice(2, -2) }
        : { type: 'text', text: part.replace(/`/g, '') },
    );

const splitCells = (line) =>
  line.trim().replace(/^\|/, '').replace(/\|$/, '').split('|').map((c) => c.trim());

export const parseBlocks = (content) => {
  const lines = String(content ?? '').replace(/\r\n/g, '\n').split('\n');
  const blocks = [];
  let i = 0;
  while (i < lines.length) {
    const line = lines[i];
    if (!line.trim()) { i += 1; continue; }

    if (TABLE_ROW.test(line)) {
      const rows = [];
      while (i < lines.length && TABLE_ROW.test(lines[i])) { rows.push(lines[i]); i += 1; }
      const hasHeader = rows.length > 1 && TABLE_SEP.test(rows[1]);
      const body = rows.filter((_, idx) => !(hasHeader && idx === 1));
      blocks.push({
        type: 'table',
        header: hasHeader ? splitCells(body[0]) : null,
        rows: (hasHeader ? body.slice(1) : body).map(splitCells),
      });
      continue;
    }

    const listMatch = line.match(BULLET) ? 'ul' : line.match(ORDERED) ? 'ol' : null;
    if (listMatch) {
      const re = listMatch === 'ul' ? BULLET : ORDERED;
      const items = [];
      while (i < lines.length && re.test(lines[i])) { items.push(lines[i].match(re)[1]); i += 1; }
      blocks.push({ type: listMatch, items });
      continue;
    }

    const heading = line.match(/^#{1,4}\s+(.*)$/);
    if (heading) { blocks.push({ type: 'heading', text: heading[1] }); i += 1; continue; }

    const para = [];
    while (i < lines.length && lines[i].trim() && !TABLE_ROW.test(lines[i]) && !BULLET.test(lines[i]) && !ORDERED.test(lines[i]) && !/^#{1,4}\s/.test(lines[i])) {
      para.push(lines[i]); i += 1;
    }
    blocks.push({ type: 'p', text: para.join('\n') });
  }
  return blocks;
};
