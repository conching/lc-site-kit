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
  echo "Root commit: $(git -C "$ROOT" rev-parse HEAD 2>/dev/null || echo unknown)"
  echo "lc-core commit: $(git -C "$ROOT/plugins/lc-core" rev-parse HEAD 2>/dev/null || echo unknown)"
  echo "lc-bricks-mcp commit: $(git -C "$ROOT/plugins/lc-bricks-mcp" rev-parse HEAD 2>/dev/null || echo unknown)"
  echo "Contents: skills, workflow docs, tests, manifests, workflows, and all"
  echo "first-party plugin source (vendor/, dist/, node_modules/ excluded)."
  echo "Each file appears under a '## FILE:' header."
} >>"$OUT"

# Top-level docs
for f in README.md SETUP.md SECURITY.md; do
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

# Root CI/release workflows.
find "$ROOT/.github/workflows" -type f \( -name '*.yml' -o -name '*.yaml' \) 2>/dev/null | sort | while read -r f; do
  emit "${f#$ROOT/}" "$f" yaml
done

# Plugin source, tests, workflows, and manifests (submodules must be initialized)
for plugin in lc-core lc-bricks-mcp; do
  P="$ROOT/plugins/$plugin"
  if [ -z "$(ls -A "$P" 2>/dev/null)" ]; then
    echo "WARN: plugins/$plugin is empty — run: git submodule update --init" >&2
    continue
  fi
  find "$P" \
      -path "$P/vendor" -prune -o \
      -path "$P/dist" -prune -o \
      -path "$P/node_modules" -prune -o \
      -type f \( -name '*.php' -o -name '*.md' -o -name '*.txt' \
                 -o -name '*.yml' -o -name '*.yaml' -o -name '*.json' \
                 -o -name '*.lock' -o -name '*.xml' -o -name '*.py' \
                 -o -name '*.sh' -o -name '*.js' -o -name '*.css' \
                 -o -name '.distignore' \) -print \
    | sort | while read -r f; do
      case "$f" in
        *.php) lang=php ;; *.py) lang=python ;; *.sh) lang=bash ;;
        *.yml|*.yaml) lang=yaml ;; *.json|*.lock) lang=json ;;
        *.js) lang=javascript ;; *.css) lang=css ;; *.xml) lang=xml ;; *) lang=markdown ;;
      esac
      emit "${f#$ROOT/}" "$f" "$lang"
    done
done

echo "Wrote $OUT ($(wc -c <"$OUT" | tr -d ' ') bytes)"
