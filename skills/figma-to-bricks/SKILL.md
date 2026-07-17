---
name: figma-to-bricks
description: Ingest a Figma design file and produce everything needed to start a Bricks build — extracted design tokens, per-page section inventories, reusable-section/template candidates, an asset manifest, and a generated WordPress build plan. Use at project kickoff when handed a figma.com/design URL or file, or on "ingest this Figma design", "start the build from Figma", "extract tokens from the design", "scope this design for Bricks". Drives the Figma MCP (read side) and lc-bricks-mcp (write side); hands off page builds to bricks-build-checklist.
---

# Figma → Bricks Ingestion

**Created by Library Creative (librarycreative.co)** — part of the
[LC Site Kit](https://github.com/conching/lc-site-kit), a Figma →
WordPress/Bricks build workflow hardened on production client builds.

**Licence:** CC BY 4.0 — share and adapt freely with credit to
Library Creative.

**Feedback:** open an issue on the LC Site Kit repo.

Turns a Figma file into a build-ready package for a
Bricks build. Runs as sequenced phases; each phase emits a deliverable.
This skill OWNS ingestion (design → plan). It does NOT build pages — page
composition + verification live in **bricks-build-checklist**; hand off, do
not duplicate its rules here.

Read side = Figma MCP (`get_metadata`, `get_variable_defs`,
`get_design_context`, `get_screenshot`, `get_libraries`, `download_assets`).
Write/probe side = lc-bricks-mcp. Never guess a token, frame, or dup you
could not confirm — mark it inferred or surface it as a client decision.

Worked example throughout: a **pilot build** — 10 full-page comps on one
14,760×8,797px canvas. It is the hard case, cited only where it changes a
rule.

## Phase 0 — File classification pre-flight (MANDATORY)

Probe SCALE before choosing strategy. Never open with a page-level dump.

1. `get_libraries` → linked team/community libraries (implies shared
   variables/styles exist and are reachable). The pilot build links two
   shared libraries (a component library + a design-system library).
2. Establish page count and frames-per-canvas. One canvas holding many
   full-page comps is the timeout trap.
3. Decide access mode from scale:
   - **Small / multi-page file:** page-level `get_metadata` is fine.
   - **Large single-canvas file (observed: 10 full-page comps on one
     14,760×8,797px canvas):** page-level `get_metadata` **times out**
     (subtree too big to serialize) — you get no layer names, node-ids, or
     dims. REQUIRE frame-scoped calls with explicit node-ids for every
     subsequent tool.
4. Harvest per-frame node-ids before Phase 1+: shallow `get_metadata` on a
   frame subtree (not the page), OR ask the client for per-frame Dev-Mode
   links / to select-and-share each frame. A build cannot proceed on
   inferred node-ids — get real ones or split the file.
5. `get_variable_defs` / `get_design_context` CAN come back "nothing
   selected" even for node-ids you pass (observed on the pilot build's large
   canvas — they fell back to the desktop app's live selection; condition
   not fully mapped, so try node-id calls first and treat failure as
   expected, not exceptional). If you cannot confirm token bindings
   headlessly, STOP guessing and emit a short **Dev-Mode checklist** for the
   human (see Phase 1 fallback) instead of fabricating a palette.
6. **Design-of-record:** request the client's per-page PDF exports at
   kickoff and record their path in the plan. The PDF is the FROZEN
   approved design; the live Figma file drifts after approval (observed on a
   pilot build: node positions and layer content diverged from the approved
   PDF the same day). All downstream fidelity QA
   (bricks-build-checklist §11) measures against the PDF, not the live
   file — the live file is for node-ids, tokens, and asset exports only.

Deliverable: a recon note (scale, page/frame count, libraries, access mode,
node-id list or the reason it's blocked, PDF-of-record path). The pilot-build
recon is the reference shape.

## Phase 1 — Token extraction

Goal: a token map that seeds Bricks global styles. Two paths.

**Path A — bound variables/styles (preferred).** When `get_variable_defs`
returns real defs (multi-page file, or a human ran Dev Mode), map 1:1:

| Figma | lc-bricks-mcp tool |
|---|---|
| color variables / styles | `color_palette` (+ `global_variable` for raw tokens) |
| text styles / type ramp | `typography_scale` |
| brand color/type applied site-wide | `theme_style` |
| repeated utility patterns (eyebrow, section-header) | `global_class` |

**Path B — inference fallback (flag every value `(inferred)`).** When
bindings are unconfirmable headlessly: per-frame `get_design_context` +
`get_screenshot`, sample computed colors/type off the render. Emit a
**Dev-Mode checklist** the human runs once: open Local Variables + Text
Styles panels; Inspect a heading + a body run for exact font families +
licensing (Google/Adobe/custom — resolve before setup, it drives cost).
On the pilot build: whole palette + fonts are Path B until that checklist is
run; the sans is likely Inter via the design-system library, the display
serif unidentified.

**Tokens are NOT the whole design.** A token map carries flat colors and
type ramps — it does NOT carry hero scrims/washes (the pilot build's is a
multiply blend, invisible in metadata), icon fills baked into exported
assets, per-section overlay tints, or decorative layers. Phase 2 must
inventory those visually; the build must pixel-sample them from the
PDF-of-record (checklist §11). Assuming tokens + structure = design is how a
pilot build's round 1 shipped the wrong scrim and navy icons.

**tokens.css conventions.** Emit a tokens doc + a `tokens.css` plan. Type-
scale utility classes carry `!important` and are therefore CAPS-authoritative
— an element wearing `.xx-section-h2` cannot render a different size. For an
intentional per-design deviation, OMIT the class and set typography on the
element (deviation = opting out, not fighting the class). This is
bricks-build-checklist rule 7 — state it so the token doc doesn't fight it,
don't re-teach it.

Deliverable: tokens doc (every value tagged extracted or inferred) + tokens.css
mapping table + the Dev-Mode checklist if Path B.

## Phase 2 — Page / section inventory

Per frame, top→bottom:
- Ordered section list with a one-line purpose each.
- Per section: **CMS vs static** classification. Repeating card grids →
  query-loop + CPT candidates. Flag them explicitly:
  - news/press grid → CPT + category taxonomy + single template.
  - product/availability matrix, seasonality grids → CPT + ACF fields;
    bespoke matrices are custom builds, budget them.
- Interaction notes (sticky nav, filter pills, steppers, hovers).
- **Decorative-layer sweep (added after a pilot build's round 1):** walk the
  rendered comp band and name every non-photo layer — decorative pattern
  bands, connector rails + dots/checks, accent strips, badges, watermarks,
  overlay tints. These usually live as page-level vectors OUTSIDE the section
  frames and are exactly what a metadata-driven inventory silently drops
  (observed: a decorative hero strip, a stepper rail, a decorative pattern
  band — all missed in round 1).

Observed: 10 frames → ~10 static pages + News (CPT) + a product CPT (plus a
bespoke availability/schedule matrix). Note visible Lorem ipsum = copy not
final.

Deliverable: per-frame inventory table (frame node-id · ordered sections ·
static/CMS · interaction notes · decorative layers).

## Phase 3 — Reusable-section detection

Find sections repeated across frames → Bricks template candidates: header/nav,
footer, CTA bands, interior hero pattern, section-header pattern, card-grid
patterns, process/stepper rows.

**RULE (twice-learned on a prior build — do not violate):** templatize ONLY
EXACT content duplicates. Near-duplicates (same layout, drifted copy) are a
client copy-standardization DECISION — surface them, do not silently unify.
Unifying destroys intentional per-page variation.

Map each candidate to the build mechanism:
- header/footer/CTA band → shared `template` (build via
  `template:create_from_elements` from a first-built page subtree; place with
  `template:insert_reference`).
- After EVERY insertion, `verify:page` (order-assert the root sequence) — an
  insert lands and the page can still render in the wrong order. This is the
  handoff contract to bricks-build-checklist, flagged here so the plan sets it.

Deliverable: template-candidate table (element · appears-on frames · template
type · exact-dupe? / client-decision flag).

## Phase 4 — Asset manifest

Per frame, list: photos, vectors/icons, logos, seals, background patterns,
fonts (+ licensing status). Note format + whether an optimization pass is
needed (photo-heavy files always need one; the pilot build has heavy
photography + decorative pattern-band vectors + a circular brand seal).

**Displayed-node rule (observed on a pilot-build card):** when a comp image
is a CROP or styled variant of a larger source (Figma crop transform on the
fill, baked tint/ghost treatment), the manifest entry is the NODE export
(`download_assets` on the node, 2x — crop + effects bake in), NOT the raw
fill. Raw fills are only correct when placed uncropped/unstyled. Mark each
manifest row `raw-fill` or `node-export` explicitly.

**White/light vectors:** flag every white-on-transparent mark for the
rect-strip pipeline — Figma exports bake context rects (node-bounds +
parent fills) into "transparent" exports; verify against a dark backdrop
(checklist §2 owns the fix mechanics).

Sourcing rule: low-res exports or missing assets → try
`pdfimages -png <client.pdf>` BEFORE asking the client — placed images extract
at their PLACED resolution (RGB layer + a separate L-channel SMask = alpha;
recompose for transparency). Check extracted dims; a PDF can still embed a
low-res original. Only escalate to the client if that fails. (Same rule as
bricks-build-checklist §2 asset sourcing — applied here at ingest time.)

Deliverable: asset manifest (frame · asset · type · raw-fill/node-export ·
source/status · license · needs-optimization?), with a client punch-list for
anything missing/unlicensed.

## Phase 5 — Generated build plan

Assemble Phases 0–4 into a build-plan doc shaped like a prior build plan of
the same shape (adapt the structure to the project). Include:
- Stack + staging line; confirmed-decisions + open-items-for-client tables.
- **PDF-of-record path per page** (from Phase 0.6) — the fidelity-QA ground
  truth the checklist's §11 pass consumes.
- Design tokens section (from Phase 1, extracted/inferred tags intact).
- Information architecture + page list (from Phase 2).
- Data model: CPT/taxonomy/ACF recommendations for every CMS-classified
  section (from Phase 2). Register list-only CPTs without single pages
  (`publicly_queryable => false`).
- Component/template inventory (from Phase 3).
- **Build order: shared templates FIRST (header, footer, CTA, hero pattern),
  THEN pages** — pages insert template references, so references must exist.
- Responsive strategy: if the file has NO mobile/tablet comps, state
  responsive is DESIGNED AT BUILD TIME, not translated — flag as the top
  schedule risk and get client sign-off. (The pilot build is desktop-only,
  ~1440px.)
- Handoff line, verbatim intent: *page builds run under bricks-build-checklist
  rules, verified with lc-bricks-mcp `verify:page` / `verify:orphaned_css`,
  and each page passes the checklist §11 Design Fidelity Pass against its
  PDF-of-record before it is called done.*

Deliverable: the build-plan doc — the skill's primary end product.

## Pre-flight (enforcement) — run before delivering ingestion output

- [ ] EVERY frame inventoried, or explicitly skipped WITH a reason —
      including the decorative-layer sweep per frame.
- [ ] Every token tagged **extracted** or **inferred**; Path-B files ship the
      Dev-Mode checklist, not a silent guessed palette.
- [ ] PDF-of-record path recorded per page (or its absence flagged as a
      kickoff blocker for fidelity QA).
- [ ] Asset manifest rows marked raw-fill vs node-export; white/light
      vectors flagged for rect-strip.
- [ ] Template candidates are EXACT content dupes only; near-dupes surfaced as
      client copy decisions, not pre-unified.
- [ ] No mobile-comp assumption — if mobile/tablet absent, the plan flags
      responsive-at-build-time as a risk, not an oversight.
- [ ] Build plan references REAL node-ids (from Phase 0 harvest), never
      invented ones; if node-ids were unobtainable, the plan says so and names
      the split-file / Dev-Mode unblock step.
- [ ] Fonts resolved to family + license, or listed as an open client item.
