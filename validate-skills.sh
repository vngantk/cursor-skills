#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
SKILLS="${ROOT}/skills"
WARN_LINES=500
MAX_NAME=64
MAX_DESC=1024

errors=0
warnings=0

err() {
  echo "error: $*" >&2
  errors=$((errors + 1))
}

warn() {
  echo "warn: $*" >&2
  warnings=$((warnings + 1))
}

parse_frontmatter() {
  local file="$1"
  awk '
    BEGIN { in_fm=0 }
    NR==1 && /^---$/ { in_fm=1; next }
    in_fm && /^---$/ { exit }
    in_fm { print }
  ' "$file"
}

read_yaml_field() {
  local block="$1"
  local key="$2"
  printf '%s\n' "$block" | awk -v k="$key" '
    $0 ~ "^" k ":" {
      sub("^" k ":[[:space:]]*", "")
      if ($0 == ">-") {
        getline
        while (getline > 0 && ($0 ~ /^[[:space:]]/ || length($0) == 0)) {
          gsub(/^[[:space:]]+/, "")
          if (out != "") out = out " "
          out = out $0
        }
        print out
        exit
      }
      gsub(/^["'\'']|["'\'']$/, "")
      print
      exit
    }
  '
}

check_links() {
  local skill_dir="$1"
  local skill_md="$2"
  local link target

  while IFS= read -r link; do
    [[ -z "$link" ]] && continue
    link="${link%%#*}"
    [[ "$link" =~ ^https?:// ]] && continue
    [[ "$link" =~ ^# ]] && continue
    target="${skill_dir}/${link}"
    if [[ ! -e "$target" ]]; then
      err "$(basename "$skill_dir"): broken link in SKILL.md → ${link}"
    fi
  done < <(grep -oE '\]\([^)]+\)' "$skill_md" | sed 's/^](//;s/)$//' || true)
}

if [[ ! -d "$SKILLS" ]]; then
  echo "error: missing directory $SKILLS" >&2
  exit 1
fi

for skill_md in "$SKILLS"/*/SKILL.md; do
  [[ -f "$skill_md" ]] || continue
  skill_dir=$(dirname "$skill_md")
  folder=$(basename "$skill_dir")

  fm=$(parse_frontmatter "$skill_md")
  if [[ -z "$fm" ]]; then
    err "$folder: SKILL.md must start with YAML frontmatter (---)"
    continue
  fi

  name=$(read_yaml_field "$fm" name)
  desc=$(read_yaml_field "$fm" description)

  if [[ -z "$name" ]]; then
    err "$folder: missing frontmatter field 'name'"
  elif [[ ${#name} -gt $MAX_NAME ]]; then
    err "$folder: name exceeds ${MAX_NAME} characters"
  elif [[ ! "$name" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]]; then
    err "$folder: name must be lowercase letters, numbers, and hyphens only (got: $name)"
  elif [[ "$name" != "$folder" ]]; then
    err "$folder: folder name must match frontmatter name ($name)"
  fi

  if [[ -z "$desc" ]]; then
    err "$folder: missing or empty frontmatter field 'description'"
  elif [[ ${#desc} -gt $MAX_DESC ]]; then
    err "$folder: description exceeds ${MAX_DESC} characters"
  fi

  lines=$(wc -l < "$skill_md" | tr -d ' ')
  if [[ "$lines" -gt $WARN_LINES ]]; then
    warn "$folder: SKILL.md is ${lines} lines (>${WARN_LINES}); consider splitting references"
  fi

  check_links "$skill_dir" "$skill_md"
done

if [[ "$errors" -gt 0 ]]; then
  echo "validate-skills: ${errors} error(s), ${warnings} warning(s)" >&2
  exit 1
fi

echo "validate-skills: ok (${warnings} warning(s))"
exit 0
