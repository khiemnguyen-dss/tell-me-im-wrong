// In kết quả của claude-review.sh; exit 1 chỉ khi MODE=block và có Blocker.
const fs = require('fs');

const [, , file, mode] = process.argv;

function parse(text) {
  try {
    return JSON.parse(text);
  } catch {
    return null;
  }
}

const d = parse(fs.readFileSync(file, 'utf8'));
const r = d && !d.is_error && (d.structured_output ?? parse(d.result));
if (!r) {
  console.log('tmiw: AI review không trả kết quả hợp lệ — cho commit đi tiếp');
  process.exit(0);
}

const findings = (r.findings || []).filter((f) => f.confidence >= 80);
for (const f of findings) {
  console.log(`\n[${f.severity}] ${f.file}:${f.line ?? '?'} — ${f.title}`);
  console.log(`   ${f.why}`);
  if (f.fix) console.log(`   → ${f.fix}`);
}
console.log(`\ntmiw (${Math.round((d.duration_ms || 0) / 1000)}s): ${r.summary}`);

if (findings.some((f) => f.severity === 'Blocker')) {
  if (mode === 'block') {
    console.log('Có Blocker. Sửa rồi commit lại, hoặc bỏ qua một lần: SKIP_AI_REVIEW=1 git commit …');
    process.exit(1);
  }
  console.log('Có Blocker (chế độ warn — vẫn cho commit).');
}
