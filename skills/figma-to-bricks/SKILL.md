---
name: figma-to-bricks
description: Ingest a client Figma design file and produce everything needed to start a Bricks build — extracted design tokens, per-page section inventories, reusable-section/template candidates, an asset manifest, and a generated WordPress build plan. Use at project kickoff when handed a figma.com/design URL or file, or on "ingest this Figma design", "start the build from Figma", "extract tokens from the design", "scope this design for Bricks". Drives the Figma MCP (read side) and lc-bricks-mcp (write side); hands off page builds to bricks-build-checklist.
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
`get_design_context`, `get_screenshot`, `get_libraries`, `download_assets`,
read-only `use_figma` — load figma-use first). Write/probe side =
lc-bricks-mcp. Never guess a token, frame, or dup you could not confirm —
mark it inferred or surface it as a client decision.

Worked example throughout: a **pilot build** — 10 desktop comps on one
oversized single canvas. It is the hard case, cited only where it changes
a rule. A **small-file build** — a handful of frames — is cited where its
traps differed (payload errors, an unused library, design-system CSS beside
the file).

## Phase 0 — File classification pre-flight (MANDATORY)

Probe SCALE before choosing strategy. Never open with a page-level dump.

**Connection first.** Open with `whoami`. If the Figma tools are missing or
fail, check THIS client's MCP registry (`claude mcp list` / `/mcp` in Claude
Code; connector settings in Desktop, Cowork, claude.ai) before calling the
server down — the connector is authorized per client, and the desktop-app
server also needs Figma desktop running with its local MCP server enabled
(127.0.0.1:3845). Name the MCP client in the recon note; no Figma access →
Path B from the PDF-of-record, said up front.

1. `get_libraries` → linked team/community libraries (implies shared
   variables/styles exist and are reachable). One pilot file linked two shared libraries.
2. Establish page count and frames-per-canvas. One canvas holding many
   full-page comps is the timeout trap.
3. Decide access mode from scale:
   - **Small / multi-page file:** page-level `get_metadata` is fine.
   - **Large single-canvas file (pilot: 10 comps on one canvas):** page-level
     `get_metadata` **times out** (subtree too big to serialize) — you get
     no layer names, node-ids, or dims. REQUIRE frame-scoped calls with
     explicit node-ids for every subsequent tool.
   - **Classify a `get_metadata` failure by its error text before picking
     a fallback.** "Timed out" = scale → frame-scope, as above. "Failed to
     parse SSE message … EOF while parsing a string" = PAYLOAD, not scale:
     a text layer holds a soft line break (U+2028) that truncates the
     stream. Frame-scoping won't fix it and it is no reason to drop to
     Path B (small-file build: it failed this way at page AND frame
     level). Skip `get_metadata` for that file; use full-frame
     `get_design_context` (step 6), plus read-only `use_figma` for node
     trees with EVERY returned `characters`/`name` string sanitized. Build
     the sanitizer regex with `String.fromCharCode(0x2028, 0x2029, 13, 10,
     0x85, 11, 12)` → replace with a space; a literal `\u2028` in the script
     is decoded by the transport before Figma runs it and breaks the regex.
4. Harvest per-frame node-ids before Phase 1+: shallow `get_metadata` on a
   frame subtree (not the page) or the sanitized `use_figma` dump, OR ask
   the client for per-frame Dev-Mode links / to select-and-share each
   frame. A build cannot proceed on inferred node-ids — get real ones or
   split the file.
5. **"Nothing selected" is a TRANSPORT-mode failure, not canvas-scale
   degradation.** `get_variable_defs` / `get_design_context` can return
   "nothing selected" even for valid node-ids you pass — the server has
   fallen back to the desktop app's LIVE SELECTION. Classify this in
   pre-flight with a cheap probe (`whoami` + one frame-scoped
   `get_metadata` on a short timeout). The unblock is PROCEDURAL, not
   technical: have the user open the target file in the Figma DESKTOP app
   and keep it frontmost — ideally with the target frame selected — for
   the duration of Phases 1–2. Do that BEFORE falling back to render-based
   inference (Path B), which is the expensive fallback. Put the same line
   in the user-facing Dev-Mode checklist: *"keep the file open in Figma
   desktop while the skill runs."*
6. **`get_design_context` often SUCCEEDS where `get_metadata` fails.**
   For any frame whose `get_metadata` times out or fails to parse, try a
   FULL-FRAME `get_design_context` before concluding the frame is
   unreadable — it
   returns declared typography, geometry, copy and short-lived asset URLs,
   which replaces most PDF pixel forensics. Recipe order:
   (1) `get_design_context` for declared truth + copy + vectors,
   (2) the PDF for photo extraction at placed resolution and as the frozen
   design-of-record cross-check, (3) pixel measurement ONLY for what
   neither provides (baked opacities/blends — solve per-channel alpha).
   If token bindings still can't be confirmed, STOP guessing and emit a
   short **Dev-Mode checklist** for the human (see Phase 1 fallback)
   instead of fabricating a palette.
7. **Design-of-record:** request the client's per-page PDF exports at
   kickoff and record their path in the plan. The PDF is the FROZEN
   approved design; the live Figma file drifts after approval (observed on the
   pilot: node positions and layer content diverged from the approved PDF
   the same day). All downstream fidelity QA
   (bricks-build-checklist §11) measures against the PDF, not the live
   file — the live file is for node-ids, tokens, and asset exports only.
8. **Design-system source files:** list the client's design folder for the
   files the design system was built from — `*.html` / `*.css` sheets,
   `tokens*.json`, `*.tokens`, a Tokens Studio export — and grep them for
   `:root` custom properties and font sources (`font-family`,
   `use.typekit.net`, `fonts.googleapis.com`). They carry what Figma rarely
   binds: spacing scale, section padding, gutters, max widths, radii,
   motion, semantic aliases, and the web font's family name (small-file
   build: HTML design sheets beside the Figma file held dozens of colours
   and the whole spacing/motion layer; an Adobe Fonts family name in their
   CSS settled licensing in one grep). Search the client's folder, not the
   whole synced drive, and report "none" only after that search completed.

Deliverable: a recon note (MCP client, scale, page/frame count, libraries,
access mode, node-id list or the reason it's blocked, PDF-of-record path,
design-system source files or "none found"). The pilot recon is the
reference shape.

## Phase 1 — Token extraction

Goal: a token map that seeds Bricks global styles. Two paths; either way
the design-system source files (Phase 0.8) fill what Figma doesn't bind.

**Tag every value with its source:** `[fig]` bound Figma variable/style ·
`[decl]` raw value declared on the node (`get_design_context`) · `[css]`
design-system source file · `[pdf]` measured off the PDF-of-record ·
`(inferred)` sampled from a render. **On conflict:** what the comps
actually apply beats a library style they don't use (Path A check below);
a binding the comps do use beats the CSS sheet; the sheet fills only what
Figma leaves unbound. List EVERY cross-source conflict as a designer
question (small-file build: a named colour one shade apart between Figma
and the CSS; button type a few px apart).

**Path A — bound variables/styles (preferred).** When `get_variable_defs`
returns real defs (multi-page file, or a human ran Dev Mode), map 1:1 —
provisionally, until the as-used check below:

| Figma | lc-bricks-mcp tool |
|---|---|
| color variables / styles | `color_palette` (+ `global_variable` for raw tokens) |
| text styles / type ramp | `typography_scale` |
| brand color/type applied site-wide | `theme_style` |
| repeated utility patterns (eyebrow, section-header) | `global_class` |

**Only palette colours are a proven var path.** Before lc-bricks-mcp 2.1.2,
`global_variable` AND `typography_scale` store names with a leading `--`,
Bricks emits `----name`, and every `var(--name)` resolves empty (observed
on a fresh 2.1.1 install). Map the type ramp to `typography_scale` and raw
tokens to `global_variable` only where the site runs ≥ 2.1.2; otherwise the
tokens doc gives type sizes as literal px and non-colour tokens as a
`:root{}` block in the lc-core site-config inline style. The checklist §7
emitted-CSS probe decides either way — a success response is not evidence.

**Check Path A against the comps before it seeds anything.** A variable
that exists is not one that's used. After Phase 2, compute the text-run
binding rate (bound style vs raw values) and list the raw
size/line-height/weight combos that repeat 3+ times across frames. Low
rate → the build scale is the repeated as-used values (`[decl]`/`[pdf]`)
and "rebind, or accept as-used?" goes to the designer; record both in the
tokens doc. Small-file build: the linked library's H2 and body styles sat
well below the raw sizes every comp actually set — a bindings-only map
would have shipped type ~25% small.

**Path B — inference fallback (flag every value `(inferred)`).** When
bindings are unconfirmable headlessly: per-frame `get_design_context` +
`get_screenshot`, sample computed colors/type off the render. Emit a
**Dev-Mode checklist** the human runs once: open Local Variables + Text
Styles panels; Inspect a heading + a body run for exact font families +
licensing (Google/Adobe/custom — resolve before setup, it drives cost).
A design-system CSS from Phase 0.8 answers the font line first: its
`font-family` / font-host URL names the licence source.
On the pilot, the whole palette + fonts stayed Path B until that checklist
was run.

**Tokens are NOT the whole design.** A token map carries flat colors and
type ramps — it does NOT carry hero scrims/washes (the pilot's is a multiply
blend, invisible in metadata), icon fills baked into exported assets,
per-section overlay tints, or decorative layers. Phase 2 must inventory
those visually; the build must pixel-sample them from the PDF-of-record
(checklist §11). Assuming tokens + structure = design is how a round-1 build
shipped the wrong scrim and wrongly-filled icons.

**tokens.css conventions.** Emit a tokens doc + a `tokens.css` plan. Type-
scale utility classes carry `!important` and are therefore CAPS-authoritative
— an element wearing `.xx-section-h2` cannot render a different size. For an
intentional per-design deviation, OMIT the class and set typography on the
element (deviation = opting out, not fighting the class). This is
bricks-build-checklist rule 7 — state it so the token doc doesn't fight it,
don't re-teach it.

Deliverable: tokens doc (every value source-tagged, conflicts listed as
designer questions, Path A binding rate recorded) + tokens.css mapping
table + the Dev-Mode checklist if Path B.

## Phase 2 — Page / section inventory

**Metadata availability is PER-FRAME, not per-file.** Expect a mix of
successes and timeouts across frames in the same canvas, and define the
fallback pair per frame: metadata where it works; full-res
`get_screenshot` + a hand-built section table where it doesn't, with
node-id harvest deferred to build time.

**Fan out above ~4 frames.** Per-frame inventory is the right shape for
parallel subagents — one agent per 2–3 frames, each returning a DISTILLED
table, never raw XML. (Sequential per-frame inventory on a 10-frame file
is the slow path for no accuracy gain.) Budget ~11 min and ~240k tokens per
frame of agent work (observed, one agent per frame) — fine for a kickoff,
but size the fan-out to it.

**Union the variable-defs sweep across ALL frames.** These calls are cheap
and per-frame, and binding coverage differs frame to frame — on one pilot
file a whole frame bound zero variables, while a single other frame was
the only one binding "Text". A single-frame sweep under-reports the token
set.

Per frame, top→bottom:
- Ordered section list with a one-line purpose each.
- Per section: **CMS vs static** classification. Repeating card grids →
  query-loop + CPT candidates. Flag them explicitly:
  - news/press grid → CPT + category taxonomy + single template.
  - product/availability matrix, seasonality grids → CPT + ACF fields; bespoke
    matrices are custom builds, budget them.
- Interaction notes (sticky nav, filter pills, steppers, hovers).
- **Type as set:** per text role (H1, H2, kicker, body, button), the
  declared family/size/line-height/weight/tracking and whether the run binds
  a library style or sets raw values — the input to Phase 1's Path A check.
- **Decorative-layer sweep (added after a pilot build's round 1):** walk the
  rendered comp band and name every non-photo layer — decorative pattern
  bands, connector rails + dots/checks, accent strips, badges, watermarks,
  overlay tints. These usually live as page-level vectors OUTSIDE the section
  frames and are exactly what a metadata-driven inventory silently drops
  (observed: an accent hero strip, a stepper rail, a decorative pattern band
  — all missed in round 1).

Observed: 10 frames → ~10 static pages + News (CPT) + a product CPT (plus a
bespoke availability/schedule matrix). Note visible Lorem ipsum = copy not
final.

Deliverable: per-frame inventory table (frame node-id · ordered sections ·
static/CMS · interaction notes · type as set · decorative layers).

## Phase 3 — Reusable-section detection

Find sections repeated across frames → Bricks template candidates: header/nav,
footer, CTA bands, interior hero pattern, section-header pattern, card-grid
patterns, process/stepper rows.

**RULE (twice-learned on prior builds — do not violate):** templatize ONLY EXACT
content duplicates. Near-duplicates (same layout, drifted copy) are a client
copy-standardization DECISION — surface them, do not silently unify. Unifying
destroys intentional per-page variation.

Map each candidate to the build mechanism:
- header/footer/CTA band → shared `template` (build via
  `template:create_from_elements` from a first-built page subtree; place with
  `template:insert_reference`).
- pattern repeated with per-page content (interior hero, CTA band with
  varying copy) → a Bricks **component** with properties ONLY IF a
  one-heading probe component, instantiated on a staging page, renders when
  the page is curled — else per-page sections sharing one global class for
  the pattern CSS. Write it into the plan as that conditional, never as a
  default: on lc-bricks-mcp 2.1.1 instances rendered an empty `<main>`
  after the full component was already built. 2.1.3 fixes the writer;
  probe anyway — a create/instantiate success response describes the
  write, not the render.
- After EVERY insertion, `verify:page` (order-assert the root sequence) — an
  insert lands and the page can still render in the wrong order. This is the
  handoff contract to bricks-build-checklist, flagged here so the plan sets it.

Deliverable: template-candidate table (element · appears-on frames · mechanism
(template / component-if-probe-passes / class-styled sections) · exact-dupe? /
client-decision flag).

## Phase 4 — Asset manifest

Per frame, list: photos, vectors/icons, logos, seals, background patterns,
fonts (+ licensing status). Note format + whether an optimization pass is
needed (photo-heavy files always need one; the pilot build has heavy
photography + decorative pattern-band vectors + a circular brand seal).

**Displayed-node rule (observed on a pilot-build card):** when a comp image is a CROP or
styled variant of a larger source (Figma crop transform on the fill, baked
tint/ghost treatment), the manifest entry is the NODE export
(`download_assets` on the node, 2x — crop + effects bake in), NOT the raw
fill. Raw fills are only correct when placed uncropped/unstyled. Mark each
manifest row `raw-fill` or `node-export` explicitly.

**Precondition:** a node export bakes in ANYTHING composited over the crop
region — overlapping text, badges, scrims. Check the region against the
comp first; if something overlaps, extract the embedded source object and
solve its blend separately. Verify every asset in ISOLATION, not only in
place. Related trap for icon slots: a node's `rawImages` are the
designer's uploaded source fills (full alpha), while the node `export`
bakes the white card behind them — for transparent icons take `rawImages`.

**White/light vectors:** flag every white-on-transparent mark for the
rect-strip pipeline — Figma exports bake context rects (node-bounds +
parent fills) into "transparent" exports; verify against a dark backdrop
(checklist §2 owns the fix mechanics).

**The PDF-measured manifest wins on framing.** When the asset pass measures
a placement that contradicts a Phase 2 decorative-layer note (anchor,
position, zoom), amend that inventory row in place or mark it "superseded
by manifest row N" — never leave both standing. Section briefs take image
framing from the manifest, not the inventory. (Observed: the inventory said
center-bottom, the manifest measured a different anchor and zoom; the stale
note reached a section brief and would have shifted the image by hundreds
of px.)

Sourcing rule: low-res exports or missing assets → try
`pdfimages -png <client.pdf>` BEFORE asking the client — placed images extract
at their PLACED resolution (RGB layer + a separate L-channel SMask = alpha;
recompose for transparency). Check extracted dims; a PDF can still embed a
low-res original. Only escalate to the client if that fails. (Same rule as
bricks-build-checklist §2 asset sourcing — applied here at ingest time.)

**Render REGIONS, not pages.** For vector/icon extraction use
`pdftoppm -x -y -W -H` region crops plus channel math (colour-key,
unmultiply, circular mask) — never a full-page `pdftoppm` render fed to a
per-pixel PIL loop. `-r 144` = 2x native for images placed at 144ppi;
`pdftotext -bbox-layout` is the fastest way to get exact ink boxes for
copy + geometry. Where Dev Mode is reachable, `get_design_context` on the
node answers most of this in one call — prefer it over pixel forensics.

Deliverable: asset manifest (frame · asset · type · raw-fill/node-export ·
measured framing · source/status · license · needs-optimization?), with a
client punch-list for anything missing/unlicensed.

## Phase 5 — Generated build plan

Assemble Phases 0–4 into a build-plan doc shaped like a prior build plan of
the same shape (adapt the structure to the project). Include:
- Stack + staging line; confirmed-decisions + open-items-for-client tables.
- **PDF-of-record path per page** (from Phase 0.7) — the fidelity-QA ground
  truth the checklist's §11 pass consumes.
- Design tokens section (from Phase 1, source tags and designer questions
  intact).
- Information architecture + page list (from Phase 2).
- Data model: CPT/taxonomy/ACF recommendations for every CMS-classified
  section (from Phase 2). Register list-only CPTs without single pages
  (`publicly_queryable => false`).
- Component/template inventory (from Phase 3).
- **Build order: shared templates FIRST (header, footer, CTA, hero pattern),
  THEN pages** — pages insert template references, so references must exist.
  If the plan proposes components, the one-heading component probe runs
  before any of them is built.
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
- [ ] Every token source-tagged (`[fig]` / `[decl]` / `[css]` / `[pdf]`) or
      **inferred**, and every cross-source conflict listed as a designer
      question; Path-B files ship the Dev-Mode checklist, not a silent
      guessed palette.
- [ ] Path A type scale checked against the type as set (binding rate
      recorded); a library the comps don't use is a designer question, not
      the build scale.
- [ ] Var-backed tokens mapped only to paths that emit clean vars on the
      site's lc-bricks-mcp (palette colours always; `typography_scale` /
      `global_variable` only on ≥ 2.1.2) — else literal px / lc-core `:root{}`.
- [ ] PDF-of-record path recorded per page (or its absence flagged as a
      kickoff blocker for fidelity QA).
- [ ] Asset manifest rows marked raw-fill vs node-export; white/light
      vectors flagged for rect-strip; inventory notes the manifest
      contradicts are amended or marked superseded.
- [ ] Template candidates are EXACT content dupes only; near-dupes surfaced as
      client copy decisions, not pre-unified. Components appear only as
      "component if the probe passes, else class-styled sections".
- [ ] No mobile-comp assumption — if mobile/tablet absent, the plan flags
      responsive-at-build-time as a risk, not an oversight.
- [ ] Build plan references REAL node-ids (from Phase 0 harvest), never
      invented ones; if node-ids were unobtainable, the plan says so and names
      the split-file / Dev-Mode unblock step.
- [ ] Fonts resolved to family + license, or listed as an open client item.
