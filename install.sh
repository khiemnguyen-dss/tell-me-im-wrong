#!/bin/sh
# curl -fsSL https://raw.githubusercontent.com/khiemnguyen-dss/tell-me-im-wrong/main/install.sh | sh
#   ... | sh -s -- cursor antigravity   chỉ cài cho agent được nêu tên
#   ... | sh -s -- --remove             gỡ khỏi mọi agent
set -eu

NAME="tell-me-im-wrong"
TARBALL="https://github.com/khiemnguyen-dss/$NAME/archive/refs/heads/main.tar.gz"
STORE="$HOME/.agents/skills"
CLAUDE_HOME="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
CODEX_HOME="${CODEX_HOME:-$HOME/.codex}"

# key|tên hiển thị|thư mục có nghĩa là agent đã cài|thư mục skills global
AGENTS="claude|Claude Code|$CLAUDE_HOME|$CLAUDE_HOME/skills
cursor|Cursor|$HOME/.cursor|$HOME/.cursor/skills
antigravity|Antigravity|$HOME/.gemini/antigravity|$HOME/.gemini/antigravity/skills
codex|Codex|$CODEX_HOME|$CODEX_HOME/skills
copilot|GitHub Copilot|$HOME/.copilot|$HOME/.copilot/skills"

remove=0
wanted=""
for arg in "$@"; do
  case "$arg" in
    --remove) remove=1 ;;
    *) wanted="$wanted $arg" ;;
  esac
done

is_wanted() {
  [ -z "$wanted" ] && [ -d "$2" ] && return 0
  case " $wanted " in *" $1 "*) return 0 ;; esac
  return 1
}

if [ "$remove" = 0 ]; then
  tmp=$(mktemp -d)
  trap 'rm -rf "$tmp"' EXIT
  curl -fsSL "$TARBALL" | tar -xz -C "$tmp" --strip-components=2 "$NAME-main/skills/$NAME"
  mkdir -p "$STORE"
  rm -rf "${STORE:?}/$NAME"
  mv "$tmp/$NAME" "$STORE/$NAME"
fi

count=0
while IFS='|' read -r key label home dir; do
  is_wanted "$key" "$home" || continue
  rm -rf "${dir:?}/$NAME"
  if [ "$remove" = 1 ]; then
    echo "  - $label"
  else
    mkdir -p "$dir"
    ln -s "$STORE/$NAME" "$dir/$NAME" 2>/dev/null || cp -R "$STORE/$NAME" "$dir/$NAME"
    echo "  + $label  ->  $dir/$NAME"
  fi
  count=$((count + 1))
done <<EOF
$AGENTS
EOF

if [ "$remove" = 1 ]; then
  rm -rf "${STORE:?}/$NAME"
  echo "Đã gỡ $NAME."
elif [ "$count" = 0 ]; then
  echo "Không thấy agent nào (claude, cursor, antigravity, codex, copilot)."
  echo "Chỉ định tay: curl -fsSL .../install.sh | sh -s -- claude cursor"
  exit 1
else
  echo "Xong. Mở phiên/cửa sổ agent mới để nạp skill."
fi
