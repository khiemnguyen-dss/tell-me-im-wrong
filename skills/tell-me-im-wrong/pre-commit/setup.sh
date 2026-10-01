#!/bin/sh
# Lắp gate pre-commit vào repo hiện tại: eslint → prettier → tsc → Claude review, cộng commitlint.
# Chạy ở bất kỳ đâu trong repo: sh ~/.agents/skills/tell-me-im-wrong/pre-commit/setup.sh
# Không ghi đè config sẵn có của repo — chỉ tạo phần còn thiếu.
set -eu

TPL=$(cd "$(dirname "$0")" && pwd)/templates
MARK="tell-me-im-wrong"

ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || { echo "Không phải git repo."; exit 1; }
cd "$ROOT"
[ -f package.json ] || { echo "Gốc repo không có package.json — gate này dành cho repo JS/TS."; exit 1; }
node -e 'const [a,b]=process.versions.node.split(".").map(Number);process.exit(a>20||(a===20&&b>=17)?0:1)' 2>/dev/null \
  || { echo "Cần Node.js ≥ 20.17."; exit 1; }

has() { ls $1 >/dev/null 2>&1; }
pkg_has() { node -e 'process.exit(require("./package.json")[process.argv[1]]?0:1)' "$1"; }
dep_has() { node -e 'const p=require("./package.json");process.exit({...p.dependencies,...p.devDependencies}[process.argv[1]]?0:1)' "$1"; }
ours() { [ -f "$1" ] && grep -q "$MARK" "$1"; }

if [ -f pnpm-lock.yaml ]; then add="pnpm add -D"; [ -f pnpm-workspace.yaml ] && add="$add -w"
elif [ -f yarn.lock ]; then add="yarn add -D"
elif [ -f bun.lockb ] || [ -f bun.lock ]; then add="bun add -d"
else add="npm install -D"; fi

ts=""; react=""
[ -n "$(git ls-files 'tsconfig.json' '*/tsconfig.json')" ] && ts=1
git ls-files 'package.json' '*/package.json' | xargs grep -l '"react"' >/dev/null 2>&1 && react=1

eslint=""; prettier=""; commitlint=""; lintstaged=""
has "eslint.config.* .eslintrc*" || pkg_has eslintConfig || eslint=1
if has "eslint.config.mjs" && ours eslint.config.mjs; then eslint=1; fi
has ".prettierrc* prettier.config.*" || pkg_has prettier && prettier=1
has ".lintstagedrc* lint-staged.config.*" || pkg_has lint-staged || lintstaged=1
ours lint-staged.config.mjs && lintstaged=1
if ! has "commitlint.config.* .commitlintrc*" && ! pkg_has commitlint; then
  # Chỉ bật khi repo đã quen Conventional Commits, tránh chặn commit của team chưa dùng
  total=$(git log -20 --format=%s 2>/dev/null | wc -l | tr -d ' ')
  conv=$(git log -20 --format=%s 2>/dev/null | grep -cE '^[a-z]+(\([^)]*\))?!?: ' || true)
  [ "$total" = 0 ] || [ $((conv * 2)) -ge "$total" ] && commitlint=1
fi

deps="husky@^9 lint-staged@^16"
[ -n "$eslint" ] && deps="$deps eslint@^9 @eslint/js@^9 globals"
[ -n "$eslint" ] && [ -n "$ts" ] && deps="$deps typescript-eslint@^8"
[ -n "$eslint" ] && [ -n "$react" ] && deps="$deps eslint-plugin-react-hooks@^7"
[ -n "$commitlint" ] && deps="$deps @commitlint/cli@^20 @commitlint/config-conventional@^20"
[ -n "$prettier" ] && ! dep_has prettier && deps="$deps prettier@^3"

echo "→ $add $deps"
# shellcheck disable=SC2086
$add $deps

node -e '
const fs = require("fs");
const p = JSON.parse(fs.readFileSync("package.json", "utf8"));
p.scripts ??= {};
const prep = p.scripts.prepare;
if (!prep) p.scripts.prepare = "husky";
else if (!/\bhusky\b/.test(prep)) p.scripts.prepare = prep + " && husky";
fs.writeFileSync("package.json", JSON.stringify(p, null, 2) + "\n");
'
npx --no -- husky >/dev/null

mkdir -p .husky/tmiw
cp "$TPL/gate.sh" "$TPL/typecheck.sh" "$TPL/claude-review.sh" "$TPL/print-review.cjs" .husky/tmiw/
chmod +x .husky/tmiw/*.sh

install_hook() {
  if [ ! -f ".husky/$1" ] || ours ".husky/$1"; then
    cp "$TPL/$1" ".husky/$1"
  elif ! grep -q "$2" ".husky/$1"; then
    printf '\n' >> ".husky/$1"
    cat "$TPL/$1" >> ".husky/$1"
  else
    echo "! .husky/$1 đã gọi $2 — giữ nguyên, tự gộp với $TPL/$1"
  fi
  chmod +x ".husky/$1"
}

if [ -n "$lintstaged" ]; then
  install_hook pre-commit lint-staged
  {
    echo "// $MARK — chạy tuần tự (--concurrent false): lớp sau chỉ chạy khi lớp trước pass"
    echo "const q = (files) => files.map((f) => JSON.stringify(f)).join(' ');"
    echo
    echo "export default {"
    echo "  '*.{js,jsx,mjs,cjs,ts,tsx,mts,cts}': (files) =>"
    echo "    \`sh .husky/tmiw/gate.sh eslint eslint --fix --max-warnings=0 --no-warn-ignored \${q(files)}\`,"
    if [ -n "$prettier" ]; then
      echo "  '*': (files) => ["
      echo "    \`prettier --write --ignore-unknown \${q(files)}\`,"
    else
      echo "  '*': () => ["
    fi
    echo "    'sh .husky/tmiw/typecheck.sh',"
    echo "    'bash .husky/tmiw/claude-review.sh',"
    echo "  ],"
    echo "};"
  } > lint-staged.config.mjs
else
  echo "! Repo đã có config lint-staged — không sửa. Thêm vào cuối config đó:"
  echo "    '*': () => ['sh .husky/tmiw/typecheck.sh', 'bash .husky/tmiw/claude-review.sh']"
  echo "  và chạy lint-staged với --concurrent false."
fi

if [ -n "$eslint" ]; then
  {
    echo "// $MARK — khởi đầu tối thiểu, thêm rule theo lỗi thật gặp trong review"
    echo "import js from '@eslint/js';"
    echo "import globals from 'globals';"
    [ -n "$ts" ] && echo "import tseslint from 'typescript-eslint';"
    [ -n "$react" ] && echo "import reactHooks from 'eslint-plugin-react-hooks';"
    echo
    echo "export default ["
    echo "  { ignores: ['**/node_modules/**', '**/dist/**', '**/build/**', '**/coverage/**'] },"
    echo "  js.configs.recommended,"
    echo "  { languageOptions: { globals: { ...globals.browser, ...globals.node } } },"
    [ -n "$ts" ] && echo "  ...tseslint.configs.recommended.map((c) => ({ ...c, files: ['**/*.{ts,tsx,mts,cts}'] })),"
    if [ -n "$react" ]; then
      echo "  { files: ['**/*.{js,jsx}'], languageOptions: { parserOptions: { ecmaFeatures: { jsx: true } } } },"
      echo "  {"
      echo "    files: ['**/*.{js,jsx,ts,tsx}'],"
      echo "    plugins: { 'react-hooks': reactHooks },"
      echo "    rules: { 'react-hooks/rules-of-hooks': 'error', 'react-hooks/exhaustive-deps': 'warn' },"
      echo "  },"
    fi
    echo "];"
  } > eslint.config.mjs
fi

if [ -n "$commitlint" ]; then
  has "commitlint.config.*" || cp "$TPL/commitlint.config.mjs" .
  install_hook commit-msg commitlint
fi

echo
echo "Đã lắp gate vào $ROOT:"
echo "  eslint      $([ -n "$eslint" ] && echo "tạo eslint.config.mjs" || echo "dùng config sẵn có")"
echo "  prettier    $([ -n "$prettier" ] && echo "bật (theo config sẵn có)" || echo "tắt — repo chưa có config prettier")"
echo "  tsc         $([ -n "$ts" ] && echo "bật cho mọi thư mục có tsconfig.json" || echo "tắt — không có tsconfig.json")"
echo "  commitlint  $([ -n "$commitlint" ] && echo "bật" || echo "tắt — repo đã có config hoặc chưa dùng Conventional Commits")"
echo "  Claude      chế độ warn — đổi MODE=block trong .husky/tmiw/claude-review.sh khi đã đủ tin"
echo
echo "Commit các file mới (.husky/, *.config.mjs, package.json, lockfile) để cả team cùng dùng."
