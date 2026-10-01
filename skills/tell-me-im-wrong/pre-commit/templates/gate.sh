#!/bin/sh
# gate.sh <tên> <lệnh...> — ghi kết quả thật vào tmiw-gates để claude-review.sh đọc
name=$1
shift
gates="$(git rev-parse --git-dir)/tmiw-gates"
if "$@"; then
  echo "$name PASS" >> "$gates"
else
  echo "$name FAIL" >> "$gates"
  exit 1
fi
