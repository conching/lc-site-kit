# LC Site Kit

A complete **Figma → WordPress/Bricks build workflow**: two Claude skills
that turn a client Figma file into a planned, built, and *verified* Bricks
site, plus the two WordPress plugins that make the write side possible.
Built and hardened by [Library Creative](https://librarycreative.co) on
production client builds.

## Why this exists

AI-driven page building fails in predictable ways: guessed design tokens,
sections that render in the wrong order, images cropped through their
baked-in logos, CSS that silently loses to specificity ties, and pages that
pass a structural check while looking nothing like the approved comp. Every
rule in this kit exists because one of those failures shipped once and got
codified so it never ships again.

## What's in the box

| Component | What it is |
|---|---|
| [skills/figma-to-bricks](skills/figma-to-bricks/SKILL.md) | Ingestion skill: Figma file → design tokens, per-page section inventories, reusable-template candidates, asset manifest, and a generated build plan |
| [skills/bricks-build-checklist](skills/bricks-build-checklist/SKILL.md) | Build + verification skill: page-composition rules, CSS/query-loop/image gotchas, a verification recipe, and a per-page Design Fidelity Pass against the approved design |
| [plugins/lc-core](https://github.com/conching/lc-core) *(submodule)* | Site-agnostic base WP plugin: per-site config layer, config-driven CSV importer, kses allowlists for CSS-only patterns, query-var augmenter |
| [plugins/lc-bricks-mcp](https://github.com/conching/lc-bricks-mcp) *(submodule)* | MCP server as a WP plugin — lets Claude read/write Bricks pages, templates, global classes, colors, typography, and run structural verification (`verify:page`, `verify:orphaned_css`) |
| [docs/KNOWN-ISSUES.md](docs/KNOWN-ISSUES.md) | Field lessons with working fixes, pending integration into the skills — read before auditing or extending |
| [SETUP.md](SETUP.md) | Team onboarding: site prerequisites, credentials, Claude account wiring, per-project kickoff |
| [bin/make-audit-bundle.sh](bin/make-audit-bundle.sh) | Flattens skills + docs + plugin source into one markdown file for LLM review |

## How the workflow runs

```
Figma design file
      │  read side: official Figma MCP connector
      ▼
figma-to-bricks (skill) ─ Phase 0  file-scale pre-flight (avoids the
      │                            large-canvas timeout trap)
      │                   Phase 1  token extraction (extracted vs inferred,
      │                            never guessed)
      │                   Phase 2  page/section inventory + CMS vs static
      │                   Phase 3  reusable-template detection (exact
      │                            duplicates only)
      │                   Phase 4  asset manifest (displayed-node rule,
      │                            licensing, sourcing)
      │                   Phase 5  the generated build plan
      ▼
bricks-build-checklist (skill) ─ page composition + verification:
      │     structural asserts, CSS layering rules, query-loop rules,
      │     kses-safe patterns, and the §11 Design Fidelity Pass measured
      │     against the client's frozen PDF-of-record
      │  write side: lc-bricks-mcp (MCP server plugin)
      ▼
WordPress + Bricks Builder site (lc-core installed as the base layer)
```

Two design decisions worth knowing up front:

- **The PDF is the design-of-record.** Live Figma files drift after
  approval; every fidelity check measures against the client's per-page PDF
  export, not the live file.
- **Verify structure, not just presence.** Every write is followed by a
  rendered-page assert (section order, computed styles, orphaned CSS) —
  the builder UI and screenshots both lie in automation contexts.

## Quickstart

**For a team member running builds** — follow [SETUP.md](SETUP.md):
install the two plugins on the project site, mint your own WP application
password, connect the lc-bricks-mcp and Figma MCP connectors in your
Claude account, and upload the two `skills/` folders as capabilities.

**For an auditor / LLM review:**

```bash
git clone --recurse-submodules https://github.com/conching/lc-site-kit.git
cd lc-site-kit
./bin/make-audit-bundle.sh    # → audit-bundle.md, all first-party review material
```

**For using the skills elsewhere** — the two `skills/` folders are
standard Claude skill directories (a `SKILL.md` with YAML frontmatter).
They work in claude.ai capabilities, Claude Code (`.claude/skills/`), or
any harness that loads Anthropic-style skills. CC BY 4.0: adapt them to
your own stack with credit.

## Requirements

- WordPress with **Bricks Builder** (see each plugin's readme for tested
  versions), PHP per plugin requirements.
- A Claude account with the **Figma MCP** connector (read side) and the
  **lc-bricks-mcp** connector (write side, authenticated with a WP
  application password).
- The skills assume ACF for CMS fields and reference `pdftoppm` /
  `pdfimages` (poppler) for the fidelity pass and asset sourcing.

## Versioning & releases

- Plugin zips are built inside each plugin repo (`bin/build-zip.sh`, gated
  on that repo's test suite) and published as **GitHub Releases** — zips
  are not committed here.
- The submodule pointers in this repo pin the known-good plugin versions
  for the current kit release.
- The skills are versioned by this repo's history. **This repo is the
  source of truth for the skills** — a copy uploaded to a Claude account
  is a deployment, not an editable original.

## Provenance & sanitization

The skills and plugins were extracted from real client builds and
de-identified for release: client names, design-file identifiers, and
vertical-specific details were generalized (evidence citations read
"observed on a pilot build"). All technical rules, incident lessons, and
concrete numbers are preserved as learned. lc-bricks-mcp is forked from
[cristianuibar/bricks-mcp](https://github.com/cristianuibar/bricks-mcp)
with fixes contributed back upstream.

## License

- **Skills and documentation** (`skills/`, `docs/`, this README):
  [CC BY 4.0](LICENSE) — share and adapt with credit to Library Creative.
- **Plugins** (`plugins/*` submodules): **GPL-2.0**, per the WordPress
  ecosystem — see each submodule's own LICENSE.

## Feedback

Open an issue on this repo — methodology gaps, rule corrections, and
"this failed on my build" reports all welcome.
