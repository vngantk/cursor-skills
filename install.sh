#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
SRC="${ROOT}/skills"

discover_agent_store_skills() {
  local root candidate
  local -a candidates=()

  for root in \
    "${HOME}/Library/Application Support/Cursor/AgentStores/cursor_agent_stores" \
    "${HOME}/.config/Cursor/AgentStores/cursor_agent_stores"; do
    [[ -d "$root" ]] || continue
    while IFS= read -r candidate; do
      [[ -n "$candidate" ]] && candidates+=("$candidate")
    done < <(find "$root" -type d -path '*/files/skills' 2>/dev/null | sort -u)
  done

  case ${#candidates[@]} in
    0)
      return 1
      ;;
    1)
      printf '%s' "${candidates[0]}"
      return 0
      ;;
    *)
      echo "Multiple Cursor Agent Store skills directories found:" >&2
      printf '  %s\n' "${candidates[@]}" >&2
      echo "Set CURSOR_AGENT_STORE_SKILLS to the one you want." >&2
      return 2
      ;;
  esac
}

if [[ ! -d "$SRC" ]]; then
  echo "Missing skills directory: $SRC" >&2
  exit 1
fi

if [[ -n "${CURSOR_AGENT_STORE_SKILLS:-}" ]]; then
  DEST="$CURSOR_AGENT_STORE_SKILLS"
else
  if ! DEST=$(discover_agent_store_skills); then
    rc=$?
    if [[ "$rc" -eq 2 ]]; then
      exit 1
    fi
    cat >&2 <<'EOF'
Could not find a Cursor Agent Store skills directory.

Install Cursor and sign in once, or set the destination explicitly:

  CURSOR_AGENT_STORE_SKILLS="/path/to/files/skills" ./install.sh

On macOS, skills usually live under:
  ~/Library/Application Support/Cursor/AgentStores/cursor_agent_stores/<id>/files/skills
EOF
    exit 1
  fi
fi

mkdir -p "$DEST"

rsync -a --exclude '.DS_Store' "${SRC}/" "${DEST}/"

echo "Installed skills from:"
echo "  $SRC"
echo "into:"
echo "  $DEST"
