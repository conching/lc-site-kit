# LC Site Kit

The Library Creative Figma → WordPress/Bricks factory: everything needed to
take a client Figma design file to a built, verified Bricks site, packaged
for team distribution and external audit.

## Component map

```
Figma design file
      │  (read side: Figma MCP — official connector)
      ▼
skills/figma-to-bricks ──── ingestion: tokens, section inventories,
      │                     template candidates, asset manifest, build plan
      ▼
skills/bricks-build-checklist ── page composition + verification rules
      │  (write side: lc-bricks-mcp — MCP server, WP plugin)
      ▼
WordPress + Bricks Builder site
      └─ plugins/lc-core ─── site-agnostic base plugin: config layer,
                             importer, kses allowlists, query filters
```

- **skills/** — the two Claude skills that drive the workflow. This repo is
  their **source of truth**; uploading them to a Claude account is a
  *deployment*, not storage. Edit here, commit, then re-upload.
- **plugins/lc-core** *(git submodule → [conching/lc-core](https://github.com/conching/lc-core), currently **private**)* —
  base WP plugin installed on every kit site.
- **plugins/lc-bricks-mcp** *(git submodule → [conching/lc-bricks-mcp](https://github.com/conching/lc-bricks-mcp), public)* —
  the MCP server plugin that lets Claude read/write Bricks content.
- **docs/** — workflow docs and [KNOWN-ISSUES.md](docs/KNOWN-ISSUES.md),
  field lessons not yet folded into the skills. Read these before auditing
  or extending the skills.
- **bin/make-audit-bundle.sh** — flattens skills + plugin source + docs into
  a single markdown file for handing to an LLM that can't browse a repo.

## Getting started

Team onboarding lives in [SETUP.md](SETUP.md). For an external audit, run:

```bash
git submodule update --init
./bin/make-audit-bundle.sh          # writes audit-bundle.md
```

## Versioning & releases

Plugin zips are built inside each plugin repo (`bin/build-zip.sh`) and
published as GitHub Releases there — zips are not committed here. The
submodule pointers in this repo pin the known-good plugin versions for the
current kit release.

## License

Plugins are **GPL-2.0** (see each submodule's LICENSE). The skills and docs
in this repo: **license TBD — decide before making this repo public.**
Note that `lc-core` is currently a private repo; if this repo goes public,
either make lc-core public too or replace its submodule with release links.
