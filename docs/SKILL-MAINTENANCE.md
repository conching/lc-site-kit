# Skill Maintenance — where each copy lives and which one wins

The skills in this repo have three copies in play. Confusing them is how a
revision gets silently lost, which has already happened once (see
"Failure this prevents" below). Read this before editing any `SKILL.md`.

## The three copies

| Copy | Location | Role |
|---|---|---|
| **Live** | the Claude app's skills mount (`~/Library/Application Support/Claude/.../skills/<name>/SKILL.md`) | What actually loads at runtime. A **deploy target, not a source.** Per-session and effectively disposable — never author here. |
| **Internal working copy** | `_Claude Skills/skill-updates/<date>/<name>/SKILL.md` | The client-named version: real project names, real element ids, real plugin versions. **Never published.** |
| **Public source of truth** | this repo, `skills/<name>/SKILL.md` | The de-identified version. CC BY 4.0, attributed, safe to share. |

The internal and public copies are a **deliberate fork**, not a drift. The
internal one is more useful day to day (concrete examples beat placeholders);
the public one is the shareable artifact. Both must receive every new rule.

## Editing rules

1. **Always start from the live file**, not from a staged copy or from
   memory. Diff live against the most recent staged copy first — if they
   differ, understand why before choosing a base.
2. **Never edit the mount directly.** It is read-only in some environments,
   writable-but-ephemeral in others; either way the edit does not persist.
3. **Sanitize on the way into this repo, never on the way out.** Public
   content is produced *from* internal content, one direction only.
4. **Run the leak audit before every commit** (see below). It is the
   enforcement mechanism, not a formality.
5. **Both copies or neither.** A rule added to one and not the other is the
   failure mode this document exists to prevent.

## Sanitization conventions

Established in the 2026-07-28 public release; keep them consistent so the
public history reads as one voice.

| Internal | Public |
|---|---|
| the named pilot client | "a pilot build" |
| the named prior client | "a prior build" |
| client-specific plugin prefix | `lc-` or "the site core plugin" |
| a client's named render modes | "alert vs normal", "a conditional render mode" |
| culturally or regionally specific asset names | "decorative pattern band", "brand seal" |
| a client's domain vocabulary | the generic category ("product", "availability matrix") |
| Figma `fileKey`, staging hostnames, element ids | removed entirely |
| an internal-only marker in the title | plain title + attribution + licence block |

Note this table names *categories*, never the actual values — writing the
real terms here would reintroduce into a public file exactly what the
sanitization removed. Keep the real substitution list in the internal copy.

**Cross-product check.** Individually-clean examples can still triangulate:
counts that match a known client count, a specific number in a thin
vertical, or a placeholder whose vertical matches a real client. Blur
counts, widen verticals, and keep placeholder verticals different from any
real client's.

## Leak audit (run before every commit)

Keep the live pattern list in the **internal** copy of this document — it
has to contain real client names, initialisms, place names, plugin
prefixes, staging hostnames and domain vocabulary to be useful, which is
exactly what must not appear here.

```bash
# PATTERNS is maintained internally, not in this repo
grep -rniE "$PATTERNS" skills/ README.md SETUP.md docs/
```

Zero matches is the only acceptable result. Keep the pattern list current as
new clients are added — an audit that does not know a client's name cannot
find it. Run it against the built artifact too, not just the working tree:
a zip built from a working tree inherits untracked per-site files.

## Where review output goes

The `task-observer` comprehensive review produces updated skills. Its
output flow:

```
observation log  ──►  internal copy   ──►  _Claude Skills/skill-updates/<date>/
(canonical, one       (client-named)       then uploaded to the Claude app
 per user, not                             (= the live deploy)
 per project)
        │
        └──────────►  sanitize  ──►  this repo  ──►  commit + push
```

Both branches run in the same session. A review that updates only the
internal copy leaves this repo stale; a review that updates only this repo
loses the concrete examples. The review is not complete until both are
written and the leak audit passes.

## Failure this prevents

On 2026-07-16 a review produced updated skills, sanitized them, and staged
them. They were published here on 2026-07-28 — but never uploaded to the
Claude app. For three weeks the runtime skills were older than the public
ones, and the next review nearly rebased onto the wrong version because
"staged but not live" and "live but not staged" look identical from either
side alone. The fix is mechanical: diff all three copies at the start of
every review, and state explicitly which one is the base.

## Where the internal copies live

The client-named copies are versioned in a **private** sibling repo,
`lc-site-kit-internal`. This repo is its sanitized public downstream —
content flows internal → public, never the reverse.

The private repo also holds the live leak-audit pattern list and the full
substitution table (`docs/SANITIZATION-PATTERNS.md`), which cannot live here
because they must name real clients to be useful.

Internal history starts 2026-08-10. Before that the only record was dated
folders under a keep-two retention rule, so earlier revisions are gone.
