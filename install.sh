#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
SRC="${ROOT}/skills"

DEFAULT_STORE="${HOME}/Library/Application Support/Cursor/AgentStores/cursor_agent_stores/u204396733/files/skills"
DEST="${CURSOR_AGENT_STORE_SKILLS:-$DEFAULT_STORE}"

if [[ ! -d "$SRC" ]]; then
  echo "Missing skills directory: $SRC" >&2
  exit 1
fi

mkdir -p "$DEST"

rsync -a --exclude '.DS_Store' "${SRC}/" "${DEST}/"

echo "Installed skills from:"
echo "  $SRC"
echo "into:"
echo "  $DEST"
