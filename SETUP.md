# Team Setup

How to run the Figma → Bricks workflow from your own Claude account against
a project site. Three things can't be copied from anyone else's machine:
your skill uploads, your MCP connections, and your site credentials.

## 1. WordPress site prerequisites (once per project site)

1. WordPress + Bricks Builder installed (see plugin readmes for tested versions).
2. Install both kit plugins from their GitHub Releases (or build from the
   submodules with `bin/build-zip.sh` in each):
   - `lc-core-<version>.zip`
   - `lc-bricks-mcp-<version>.zip`
3. Verify the sha256 of any downloaded zip against the published checksum.
4. Configure lc-core's per-site layer: copy `config/example-config.php` →
   `config/site-config.php` in the plugin and fill in the project values.

## 2. Credentials (once per person, per site)

1. In wp-admin, create a WordPress **application password** for *your own*
   WP user (Users → Profile → Application Passwords). Never share or reuse
   another person's app password; never commit one anywhere.
2. Keep it in your password manager. It is the only secret the workflow needs.

## 3. Claude account wiring (once per person)

1. **lc-bricks-mcp connector** — add the MCP connector in your Claude
   account (claude.ai → Settings → Connectors, or `claude mcp add` in
   Claude Code), pointing at the project site's MCP endpoint with your WP
   username + application password.
   **Name the connector after the project site** (e.g. `lc-bricks-mcp-<project>`).
   The bricks-build-checklist skill's connection guard (`get_site_info`
   name match) exists because a generically-named connector can point at
   the wrong client's site.
2. **Figma MCP** — connect the official Figma connector (read side). You
   need at least view access to the client's Figma file.
3. **Skills** — upload the two folders under `skills/` as capabilities in
   your Claude account (claude.ai → Settings → Capabilities), or, in Claude
   Code, place them under `.claude/skills/` in your project.

> Skills are versioned **in this repo**. If you improve a skill during a
> build, edit it here, commit, and re-upload — don't let your uploaded copy
> drift as the only home of a lesson.

## 4. Per-project kickoff

1. Get the client Figma URL (and ask for per-page **PDF exports** — the
   skills treat the PDF as the design-of-record; the live file drifts).
2. Start a session and invoke `figma-to-bricks` with the Figma URL. It
   produces the recon note, token map, inventories, asset manifest, and the
   build plan.
3. Page builds then run under `bricks-build-checklist` rules — including
   the §11 Design Fidelity Pass against the PDF-of-record before any page
   is called done.
4. Before ending any session that committed plugin changes:
   `git log --branches --not --remotes --oneline` in each touched repo and
   push anything unpushed.

## Troubleshooting

- MCP writes hitting the wrong site → your connector name/site mismatch;
  the checklist's connection guard should have caught it — re-read §
  "Connection guard".
- Figma tools timing out on big files → that's expected on large
  single-canvas files; the figma-to-bricks Phase 0 pre-flight covers the
  frame-scoped fallback.
- Known field gotchas not yet in the skills: [docs/KNOWN-ISSUES.md](docs/KNOWN-ISSUES.md).
