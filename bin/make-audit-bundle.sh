#!/usr/bin/env bash
# Flatten the LC Site Kit into a single markdown file for LLM audit.
# Usage: ./bin/make-audit-bundle.sh [output-file]
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${1:-$ROOT/audit-bundle.md}"

emit() { # emit <label> <file>
  printf '\n\n---\n\n## FILE: %s\n\n```%s\n' "$1" "${3:-}" >>"$OUT"
  cat "$2" >>"$OUT"
  printf '\n```\n' >>"$OUT"
}

: >"$OUT"
{
  echo "# LC Site Kit — Audit Bundle"
  echo
  echo "Generated: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "Contents: skills, workflow docs, and plugin source (vendor/, dist/,"
  echo "tests/ excluded). Each file appears under a '## FILE:' header."
} >>"$OUT"

# Top-level docs
for f in README.md SETUP.md; do
  [ -f "$ROOT/$f" ] && emit "$f" "$ROOT/$f" markdown
done

# Skills
find "$ROOT/skills" -name 'SKILL.md' | sort | while read -r f; do
  emit "${f#$ROOT/}" "$f" markdown
done

# Docs
find "$ROOT/docs" -name '*.md' 2>/dev/null | sort | while read -r f; do
  emit "${f#$ROOT/}" "$f" markdown
done

# Plugin source (submodules must be initialized)
for plugin in lc-core lc-bricks-mcp; do
  P="$ROOT/plugins/$plugin"
  if [ -z "$(ls -A "$P" 2>/dev/null)" ]; then
    echo "WARN: plugins/$plugin is empty — run: git submodule update --init" >&2
    continue
  fi
  find "$P" \
      -path "$P/vendor" -prune -o \
      -path "$P/dist" -prune -o \
      -path "$P/tests" -prune -o \
      -path "$P/node_modules" -prune -o \
      -type f \( -name '*.php' -o -name '*.md' -o -name '*.txt' \
                 -o -name '*.yml' -o -name '*.py' -o -name '*.sh' \) -print \
    | sort | while read -r f; do
      case "$f" in
        *.php) lang=php ;; *.py) lang=python ;; *.sh) lang=bash ;;
        *.yml) lang=yaml ;; *) lang=markdown ;;
      esac
      emit "${f#$ROOT/}" "$f" "$lang"
    done
done

echo "Wrote $OUT ($(wc -c <"$OUT" | tr -d ' ') bytes)"
