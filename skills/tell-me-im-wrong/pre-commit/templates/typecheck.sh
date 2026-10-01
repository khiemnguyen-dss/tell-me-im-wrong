#!/bin/sh
# tsc cho từng project (thư mục có tsconfig.json) chứa file TS đang staged
gates="$(git rev-parse --git-dir)/tmiw-gates"
staged=$(git diff --cached --name-only --diff-filter=ACMR -- '*.ts' '*.tsx' '*.mts' '*.cts')
[ -z "$staged" ] && { echo "tsc NA" >> "$gates"; exit 0; }

ran=0
for cfg in $(git ls-files 'tsconfig.json' '*/tsconfig.json'); do
  dir=$(dirname "$cfg")
  [ "$dir" = . ] || echo "$staged" | grep -q "^$dir/" || continue
  (cd "$dir" && npx --no -- tsc --version >/dev/null 2>&1) || continue
  # tsconfig kiểu solution (files rỗng + references) thì --noEmit -p không kiểm gì cả
  if grep -q '"references"' "$cfg"; then args="-b"; else args="--noEmit -p tsconfig.json"; fi
  echo "tsc $args ($dir)"
  # shellcheck disable=SC2086
  (cd "$dir" && npx --no -- tsc $args) || { echo "tsc FAIL" >> "$gates"; exit 1; }
  ran=1
done
[ "$ran" = 1 ] && echo "tsc PASS" >> "$gates"
exit 0
