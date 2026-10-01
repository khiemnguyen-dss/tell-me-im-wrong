#!/usr/bin/env bash
# Lớp cuối của pre-commit: Claude Code local review diff đã staged bằng skill tell-me-im-wrong.
# Bỏ qua một lần: SKIP_AI_REVIEW=1 git commit …
set -uo pipefail

MODE=warn        # warn: chỉ in finding | block: Blocker chặn commit
MAX_LINES=800    # diff lớn hơn thì bỏ qua, để dành cho review PR
MODEL=sonnet
BUDGET_USD=1.5

[ -n "${SKIP_AI_REVIEW:-}" ] && exit 0

# lint-staged giấu output của task pass — ghi lại để .husky/pre-commit in ra sau
exec > >(tee "$(git rev-parse --git-dir)/tmiw-review.txt") 2>&1

# lint-staged chèn thư mục bin của node lên đầu PATH, có thể trỏ vào một bản claude hỏng
CLAUDE=""
for c in $(type -ap claude); do
  "$c" --version >/dev/null 2>&1 && { CLAUDE=$c; break; }
done
[ -n "$CLAUDE" ] || { echo "tmiw: không thấy claude chạy được trong PATH — bỏ qua AI review"; exit 0; }

skill=""
for d in .claude/skills "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/skills"; do
  [ -f "$d/tell-me-im-wrong/SKILL.md" ] && skill=1
done
[ -n "$skill" ] || { echo "tmiw: máy này chưa cài skill tell-me-im-wrong — bỏ qua AI review"; exit 0; }

FILES=$(git diff --cached --name-only --diff-filter=ACMR -- '*.js' '*.jsx' '*.mjs' '*.cjs' '*.ts' '*.tsx' '*.mts' '*.cts')
[ -z "$FILES" ] && exit 0
# shellcheck disable=SC2086
LINES=$(git diff --cached --numstat -- $FILES | awk '{a+=$1+$2} END{print a+0}')
[ "$LINES" -gt "$MAX_LINES" ] && { echo "tmiw: diff $LINES dòng > $MAX_LINES — bỏ qua AI review"; exit 0; }

GATES="$(git rev-parse --git-dir)/tmiw-gates"
OUT=$(mktemp)
trap 'rm -f "$OUT"' EXIT

gate() {
  if grep -q "^$1 PASS" "$GATES" 2>/dev/null; then echo PASS
  elif grep -q "^$1 NA" "$GATES" 2>/dev/null; then echo "không áp dụng cho diff này"
  else echo "SKIP — không có gate, soi kỹ lớp lỗi này"; fi
}

context() {
  echo "## Gate máy vừa chạy trên đúng nội dung sắp commit"
  echo
  echo "| Gate | Kết quả | Phủ lớp lỗi |"
  echo "|---|---|---|"
  echo "| eslint --max-warnings=0 | $(gate eslint) | biến/import thừa, rules-of-hooks, exhaustive-deps, lỗi cú pháp |"
  echo "| tsc | $(gate tsc) | sai kiểu, thiếu field, null/undefined |"
  echo "| test | SKIP — hook không chạy test | logic |"
  echo
  echo "## Nhánh: $(git rev-parse --abbrev-ref HEAD)"
  echo
  echo "## Diff đã staged ($LINES dòng)"
  echo '```diff'
  # shellcheck disable=SC2086
  git diff --cached -U15 -- $FILES
  echo '```'
}

SCHEMA='{"type":"object","properties":{
  "verdict":{"type":"string","enum":["pass","warn","block"]},
  "summary":{"type":"string"},
  "findings":{"type":"array","items":{"type":"object","properties":{
    "severity":{"type":"string","enum":["Blocker","Major","Minor"]},
    "file":{"type":"string"},"line":{"type":"integer"},
    "title":{"type":"string"},"why":{"type":"string"},"fix":{"type":"string"},
    "confidence":{"type":"integer"}},
    "required":["severity","file","title","why","confidence"]}}},
  "required":["verdict","summary","findings"]}'

echo "tmiw: Claude đang review $LINES dòng đã staged…"
context | "$CLAUDE" -p "Dùng skill tell-me-im-wrong ở chế độ pre-commit. Bối cảnh (kết quả gate + diff đã staged) nằm ở stdin." \
  --output-format json --json-schema "$SCHEMA" \
  --allowed-tools Skill Read Grep Glob "Bash(git log:*)" "Bash(git blame:*)" "Bash(git show:*)" \
  --disallowed-tools Edit Write NotebookEdit WebSearch WebFetch \
  --model "$MODEL" --max-budget-usd "$BUDGET_USD" \
  > "$OUT" 2>/dev/null || { echo "tmiw: AI review lỗi — cho commit đi tiếp"; exit 0; }

node "$(dirname "$0")/print-review.cjs" "$OUT" "$MODE"
