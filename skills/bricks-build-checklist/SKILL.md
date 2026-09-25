---
name: bricks-build-checklist
description: "Build + verification checklist for WordPress sites built with Bricks Builder via the bricks-mcp connector. Use whenever composing or editing Bricks pages/templates through MCP tools — page builds, section edits, template migrations, global CSS changes, image/tile work, query loops, responsive passes, onboarding a new site to the MCP — and before declaring any Bricks change \"done\". Codifies hard-won gotchas so client QA rounds don't re-discover them."
---

# Bricks Build Checklist

**Created by Library Creative (librarycreative.co)** — part of the
[LC Site Kit](https://github.com/conching/lc-site-kit), a Figma →
WordPress/Bricks build workflow hardened on production client builds.

**Licence:** CC BY 4.0 — share and adapt freely with credit to
Library Creative.

**Feedback:** open an issue on the LC Site Kit repo.

Build + verification rules for WP builds using Bricks + bricks-mcp.
Born from a prior build (2026-07), hardened across a pilot build
(2026-07/08). Three rules of thumb above all: **verify structure, not
just presence**, **verify appearance against the comp, not against your own
intent** (§11), and **new design rules apply retroactively to code written
before the rule existed.**

## 0. FIRST STEP: confirm which site you are pointed at

Several Bricks MCP servers expose IDENTICAL tool names (a bare
`bricks-mcp`, one `lc-bricks-mcp-<site>` per client, plus client-named
staging servers), so the target is invisible in the tool call itself.

Before ANY write: call `get_site_info` on the intended server, ECHO the
returned site URL and the tool prefix (e.g. `mcp__lc-bricks-mcp-<site>__`)
into the build plan, and do NOT write until both match the client named in
the task. A bare `bricks-mcp` carries no site name yet can target one
client's staging while a sibling server targets the same client's other
host, both live — register every site server with its site in the name.
A passed guard is the only proof you're writing to the right install.

If the server is missing from the session or `get_site_info` fails, rule
out "not registered in THIS client" before "site down": Claude Code,
Desktop and Cowork each keep their own MCP registry (`claude mcp list` or
`/mcp` in Claude Code; extension/connector settings in Desktop and Cowork).
A per-site `.mcpb` bundle can install with its config saved yet
`isEnabled: false`, and then no session loads it — check
`~/Library/Application Support/Claude/Claude Extensions Settings/<extension-id>.json`.
The credential is the bundle's `auth_basic` (OS keychain) and is the
user's to generate. A site with no server yet: `reference/release-checklist.md`
→ "New-site onboarding". With no working server, spec-only work still runs
(element JSON checked with the pre-write harness, `reference/recipes.md`).

**Then confirm the edit target matches what the client sees.** When the
client describes the LIVE site and you can only write to a staging copy,
curl both and diff the root section order (§1's grep) before building.
Report drift up front — above all a missing placement anchor ("below the
impact band" when staging lacks that band) — and either replicate the
anchor on staging or state that the preview differs. Settle the deploy
path at the same time (search memory and project notes for the site +
staging/push/migrate): surgical writes on prod, template import, or a
wholesale staging→prod push. Never propose a staging→live push from a
staging that is behind live — it deletes live work.

**Ids and structure from memory or earlier notes are hypotheses.** Other
editors rebuild sections between sessions (a logo grid became a
media carousel within a week — ids, classes and tiers all gone). Before the
first write to an existing section in a session, read it back (`page get
view:summary` or `verify:page` on the target).

## 1. After ANY structural edit: assert section ORDER, not presence

`element add` with name `template` APPENDS at root regardless of the
`position` param — root-level TEMPLATE elements always land at root.

**Plain element adds DO honor `parent_id` and `position`.** An earlier
entry here recorded "conflicting behaviors by context" after a subagent
reported adds landing at root; a source audit resolved it — the real
culprit was a root-`position` bug in the connector, not context-dependent
behavior. `element move` DOES re-parent (via `target_parent_id`). Keep the
render-verify habit below as defense-in-depth, not as a workaround for a
bug that no longer exists.

After template insertion, section removal, or any root-level change, curl
the page with a cache-buster and assert the FULL top-level sequence:

```bash
curl -s "https://SITE/PAGE/?nc=$RANDOM" | grep -oE 'id="brxe-(sec1|sec2|sec3|...)"'
```

Compare against the intended order for EVERY page touched — and for every
render mode if the site has conditional stacks (e.g. alert vs normal).
Fix with `element move` (position = index after removal from the array).

Prefer `verify:page` (stored mode = deterministic, no HTTP; `rendered:true`
= document order after template resolution) over hand-rolled curl greps
where the connector offers it.

Two traps in the assert itself:
- Sections carrying `_attributes` anchor ids render WITHOUT their
  `brxe-` id (e.g. `<section id="partner">`) — an order-grep keyed on
  `id="brxe-…"` reports them "missing" and you'll chase phantom data
  loss. Match `id="(?:brxe-)?…"` and know the page's anchor ids.
- When a batch migration touches N pages, order-assert ALL N — a batch
  that verified 2 of 6 pages shipped the same misplacement bug on the
  other 4, found by the client days later.

**A REBUILT element is a RENAMED element.** Rebuilding rather than editing
gives fresh ids, and every rule elsewhere naming the old id dies without
error — Bricks emits it, the browser parses it, nothing matches. A COPIED
element is renamed too (`template create_from_elements`, JSON import), so a
section meant to travel gets class-scoped CSS from the start (§7 selector
table). After any rebuild: grep every CSS surface for the old ids, run `verify:orphaned_css`
(a post-rebuild step, not just a pre-launch one), and re-probe at ALL
breakpoints — the responsive carrier is where dead ids hide, invisible at
desktop (a pilot build's card row: five id lists, four of them dead,
surfacing weeks later as 173px columns on a 390px phone). Sibling parity: when N
elements are meant to be identical, assert their computed geometry against
EACH OTHER in ONE probe, not each against your intent — the diff between
siblings is what the client sees, and a rebuild drifts the recipe too.

Templatization rule: only sections with EXACTLY identical content get a
shared global section template. Near-duplicates (same layout, drifted
copy) go to the client as a copy-standardization decision first —
silently unifying copy destroys intentional per-page variations.

**Components: probe the mechanism before designing around it.** Before
planning anything on Bricks components via MCP, instantiate a one-heading
probe component and curl the page (lc-bricks-mcp 2.1.1 on Bricks 2.4.1:
`component:create` left children parented to the old root id, and even a
fixed one-heading instance rendered an empty `<main>`). Empty output = build
per-page sections plus ONE global class holding the pattern CSS. To tell a
connector bug from a Bricks limitation, write the native shape raw through
`page:update_content`, bypassing the component tool: an instance's `name`
is the component ROOT's element type (e.g. `heading`), not the component
id, and property values are a MAP keyed by property id — a list of
`{id,value}` is silently ignored.

## 2. Images: bake-don't-crop, and place the DISPLAYED node

Baked/designed images (tiles with seals, labels, logos near edges) must
never render in a box of a different aspect ratio with `object-fit: cover`
— edges crop and text/logos clip.

- Canonical fix: `aspect-ratio: <img-w>/<img-h>; height: auto;` on the box.
- When this rule (or any sizing rule) is introduced mid-project, grep ALL
  existing CSS — tokens/theme CSS, template `_cssCustom`, element CSS —
  for `height: <fixed>` + `cover` patterns on image classes and fix them
  in the same pass. Old violations WILL surface as client QA later.
- Fixed-aspect thumbnail boxes must be fed a same-aspect image.
- **Displayed-node rule (observed on a pilot-build card):** when the comp shows a CROP or
  styled variant of a source image (Figma crop transform, baked tint,
  ghost overlay), export the NODE as displayed (`download_assets` on the
  node, 2x) — never place the raw fill. A raw fill is only correct when
  the comp places it uncropped and unstyled. Symptom of getting this
  wrong: "why is there a collage here?" — the raw source was a montage
  the design only sampled.
- **"It's cropped/clipped" — triage the ASSET before the CSS.** Compare the
  served file's intrinsic ratio (`naturalWidth/naturalHeight`) against the
  element's ink ratio in the comp: equal = the fault is in the box, unequal
  = the fault is in the file. Several of a pilot build's badge PNGs shipped
  with the ring cut off while their CSS (`width:86px; height:auto; object-fit:fill`)
  could not crop anything. Run it across the whole sibling SET at once —
  the outliers name themselves.
- **`object-fit: contain` exposes the img's own box.** Sites running the
  Performance Lab dominant-colour placeholder (`data-dominant-color` in the
  served markup — record it as a site trait at discovery) give every OPAQUE
  attachment `background-color: var(--dominant-color)`, which paints the
  letterbox for good, not as a load flash. Every contain-fit img (logo
  grids, badges, product tiles) needs an explicit `background-color:
  transparent`. Probe the computed `backgroundColor` of each; in a mixed
  set only the JPG-sourced logos show boxes — that split is the tell.
- **Bricks media carousel (logo bands):** converting an image grid to a
  media carousel drops every per-image class (optical-balance tiers), and
  its slides default to 300px tall. Height, per-logo scale keyed to the
  filename (never `nth-child`) and the add-a-logo steps:
  `reference/recipes.md` → "Logo bands in a media carousel".
- **Background-photo framing:** reproduce the comp's placement as a
  width-proportional size plus a vw top offset measured off the PDF (e.g.
  `129.1% auto`, top `-24.51vw`), with height
  `max(calc(100% + <offset>), <N>vw)` so taller stacked sections stay
  covered. Where an inventory
  framing note and the PDF-measured asset manifest disagree, the manifest
  wins.
- Asset sourcing, extraction and repair recipes (Figma exports that bake in
  context rects, `pdfimages` RGB+SMask recompose, icon `rawImages` vs
  `export`, the crop-as-displayed precondition, the dependency-free PPM/PNG
  pipeline when PIL is missing, uploads that keep their filename and alt):
  `reference/recipes.md` — read it when an export comes back wrong,
  low-res, cropped, or with baked-in bounds, and before any upload.

## 3. `background` shorthand must include a color

A `background:` shorthand with no color layer resets `background-color`
to transparent. Bricks lazy-load strips background-images until scroll, so
such sections flash WHITE. Automation browsers never fire the lazy
IntersectionObserver — trust computed `background-color`, not `bgImage`,
when probing. Rule: every section background written as shorthand gets a
separate `background-color: <band color>` line.

Never draw a logo or brand mark as an element's own `background-image`:
the element carries `bricks-lazy-hidden`, so the mark flashes in (and
computes `none` in probes). Put it on `#brxe-ID::before` (absolute,
`inset:0`) — the lazy class does not touch pseudo-elements — or use an
image element.

## 4. `_cssCustom` and settings-object edits REPLACE, never merge

- `element update` merges top-level keys but REPLACES whole `_cssCustom` /
  `_background` values. Always fetch the current full string first and
  diff your rewrite against it — de-uppercase overrides, `text-transform`,
  and similar one-off fixes ride along inside old strings and silently
  vanish otherwise. This bites hardest where a section's `_cssCustom`
  carries a large payload (icon data-URIs, embedded SVG) that is invisible
  in a summary view — read the full string before every edit.
- `page update_content` replaces ALL page content. No append — resend the
  full element array.
- Never pass `return_persisted: true` on a page above ~30 elements. On a
  128-element page it returned 92,892 characters across 2,728 lines —
  past the tool-result ceiling, so it spilled to a file and the two facts
  actually needed (`element_id`, `persisted`) had to be recovered with a
  parsing script. The default compact response already carries both plus
  the stripped diff; read structure back with `page get view:summary` or
  `verify:page`, which are bounded. An unbounded read-back bolted onto a
  write is the most expensive way to learn a two-field result.
- MCP `null` does NOT delete a style setting — it emits `display: ;
  position: ;`. Browsers drop the declaration, but it is dead CSS in the
  stored tree; set an explicit neutral value instead.
  `null` removal is NOT uniform: it removes query/loop keys (§5) but leaves
  STYLE keys present-and-empty. Read back the EMITTED CSS after any
  deletion — the persist response describes the write, not the artifact.

## 5. Query-loop rules

- Loop lives on the CARD element, not its wrapper (wrapper-with-hasLoop
  repeats the wrapper itself; its `#brxe-id` CSS matches nothing).
- REMOVING a loop: set `{"hasLoop": null, "query": null}`. Setting
  `hasLoop: false` FATALS the front end (Bricks isset-checks the key).
  Repoint any `{query_results_count:ID}` refs at the element that now
  owns the query.
- Loop children render with EMPTY ids — target them by class
  `.brxe-<elementid>`, never `#brxe-<elementid>` (see §7's selector table).
- **Element SETTINGS are loop-safe; only `_cssCustom` is not.** Bricks
  compiles element settings into class-based descendant selectors that
  work identically for static and looped elements. For loop children, set
  typography/spacing in SETTINGS rather than custom CSS — and note the
  compiled rule (e.g. `.brxe-LOOP .brxe-CHILD.brxe-text-link`, 0-3-0)
  BEATS a plain `.brxe-CHILD` custom-CSS rule, so custom CSS aimed at a
  loop child will silently lose.
- Bricks query objects need snake_case WP_Query keys (`post_type`,
  `posts_per_page`); camelCase silently returns zero items.
- **`meta_query` passes through; `tax_query` does NOT.** Bricks DROPS raw
  taxonomy constraints from stored loop queries (`tax_query`, `taxQuery`,
  `taxonomyQuery` all discarded). Native `meta_query` in the element's own
  query settings (`query.meta_query = [{id,key,value,compare}]` +
  `meta_query_relation`) works immediately. For a taxonomy constraint you
  need a `bricks/posts/query_vars` hook in the site plugin **keyed on
  element id** — a pilot build's grouped product loops use exactly this.
- Reserve `bricks/posts/query_vars` otherwise for AUGMENTING existing
  loops from GET params: a site core plugin hooked query_vars to inject a meta_query
  into a newly-created loop (keyed first on `_cssClasses`, then on element
  id) and it demonstrably ran for the pre-existing main loop but never
  affected the new loop — zero items under both keying schemes. A
  constraint that belongs to ONE specific loop is safer declared in that
  loop's own settings than injected imperatively by a hook.
- **Dynamic-data delivery drift** — verify what actually renders:
  - ACF-driven links need `{"type":"external","url":"{acf_tag}"}`.
    `type:"dynamic"` renders an EMPTY href.
  - There is no `{acf_select:label}` filter — set the ACF field's
    `return_format` to label instead.
  - `{post_date:F Y}` and `{post_terms_TAXONOMY:plain}` DO work in
    text elements.
- `hasLoop` on a text-basic containing `{tags}` does NOT create loop
  context — use a loop `div` with native child elements per dynamic tag.
- Load More: the interaction's `loadMoreQuery` must be the LOOP ELEMENT's
  id (e.g. "rsmlc0"), never "main" — "main" silently no-ops. A working
  loadMore preserves server-side filter query vars through the AJAX
  append and adds `brx-load-more-hidden` to the button when exhausted.
- The `pagination` element renders `display:none` + empty when its
  `query` setting doesn't resolve to a live query element — an invisible
  failure; curl the markup, don't trust the builder.
- Element conditions accept numeric compares on dynamic data, e.g.
  `{"key":"dynamic_data","compare":">","value":"6","dynamic_data":
  "{query_results_count:LOOPID}"}` — useful to hide Load More when the
  result set fits one page, or show an empty-state at 0 results.

## 6. Element attribute + id gotchas

- `_attributes` working format is an ARRAY `[{"id","name","value"}]` — an
  object map silently fails to render.
- `_attributes` id="X" REPLACES the element's `brxe-` DOM id, killing all
  `#brxe-{id}` CSS for that element. Never put an anchor id on the section
  or card itself — use an ADDITIVE element (recipe below).
- **Bricks omits ANY element whose render output is empty** — not just
  childless layout elements. A childless `div` renders nothing; so does a
  `text-basic` with `text: ""`. This is what makes the old "add a
  zero-height child `div`" advice silently produce no anchor at all.
  Diagnostic: the skipped element's `_cssCustom` STILL appears in the page
  stylesheet (element CSS is collected by walking the stored tree, markup
  by rendering it), so **CSS present + markup absent = element skipped,
  not a bad selector** — the single most misleading signature here.
  Verified on a pilot build: `grep -c 'brxe-<id>'` returned 0 across the
  whole response while `#<anchor>{...}` was present in the emitted CSS.
- **Stored but not rendered — enumerate ALL the hiding mechanisms** before
  hunting CSS: conditions (`get_conditions`), empty render (above), and the
  per-element hide flags `_hideElementFrontend` / `_hideElementBuilder` on
  the element OR ANY ANCESTOR. The flags show only in `page get
  view:detail` (large — filter it with
  `jq '.. | objects | select(has("_hideElementFrontend"))'`);
  `verify:page`, `get_conditions` and the summary view all report the
  element as present. Un-hide with
  `false`, not `null` (§4). "No conditions" is not "not hidden".
- **Working additive-anchor recipe** (render-verified on a pilot build):
  `reference/recipes.md` — read before adding any in-page anchor target.
- Element ids: exactly 6 lowercase alphanumerics; root parent must be
  integer `0` (string "0" rejected at root).
- `element remove` does NOT cascade — orphaned children STILL RENDER.
  Remove every descendant id individually, then curl-verify zero orphans
  (`verify:orphaned_css` scans stored CSS surfaces for dead `#brxe-` refs).
- Retroactivity (thrice-learned, cf. rule 2's bake-don't-crop sweep): after
  codifying any trap like the anchor-id one above, sweep the EXISTING build
  for pre-rule violations — pages built before the additive convention
  still carry anchor ids set directly on sections and orphan their CSS (run
  rule 8's orphaned-rule scan on them), AND pages built during the
  empty-`div` era carry anchors that render nothing at all. The second
  class is invisible to `verify:orphaned_css` (a skipped element has no
  dead CSS) — find it by grepping the served page for each literal anchor
  id, or by clicking every in-page `href="#…"` link.

## 7. CSS layering + layout facts

**Selector choice — Bricks' targeting is asymmetric.** Settle which case
you're in with one probe (`getElementById('brxe-X')?.className`):

| Element kind | Correct selector | Why |
|---|---|---|
| Static element | `#brxe-X` | it has the DOM id but NOT a `brxe-X` class |
| Loop child | `.brxe-X` | it has the class but an EMPTY id |
| Bare (unlinked) image | `#brxe-X, #brxe-X img` | the element IS the `img` node |
| Section that will travel (template, import, other site) | a section class via `_cssClasses`: `.band .child` | every copy regenerates the ids |

Never write `#brxe-X img` alone for a bare image — there is no inner img.
Choose the scope from the element's FUTURE: id selectors are for one-off
page elements (class scope at 0-2-0 still beats Bricks' `.brxe-block`
defaults). After `template create_from_elements`, grep the copied root's
`_cssCustom` for `#brxe-` — any hit is a portability bug; fix it on BOTH
copies before export.

- Dead paths that emit NOTHING: theme-style `general.containerWidth`,
  `css.custom`, `h1Typography`-style heading sub-keys, root
  `typography.font-family/size/color` (body type lives under
  `typographyBody`), Bricks
  global_variable entries (they're stored as AI-reference tokens only —
  use literal hex in element CSS). Trusted paths: plugin-enqueued
  tokens.css, element-level settings/`_cssCustom`, element
  `_typography:<breakpoint>`.
- **Flex key is `_direction`, NOT `_flexDirection`** — the wrong key
  silently no-ops. And `_direction` only sets `flex-direction`: a Bricks
  `div` is `display:block` by default (sections and containers are flex),
  so a div with `_direction: row` still stacks. Set `display:flex` (CSS, or
  `_display`) first and check computed `display` on the first render of
  every new structural pattern.
- **Column containers shrink-wrap by default.** A column-flex container
  with full-width row children needs `_alignItems: "stretch"` AT
  CREATION. This is the single most recurring layout bug in this stack —
  it has been re-learned at least three times.
- **Utility classes graduate.** A utility class (`.lc-card-img`,
  `.lc-pillar-*`, `.lc-arrow-link`) moves from page-scoped `_cssCustom`
  to the HEADER template's CSS the first time a SECOND page uses it.
  Page-scoped CSS is for page-specific rules only; a "site-wide" utility
  living in one page's CSS is a latent bug on every other page.
- **`text-link` renders NO children.** For a clickable composite, use the
  stretched-link pattern: `position:relative` on the card + an inner link
  with `::after{content:"";position:absolute;inset:0}`.
- **Container discipline (a pilot build's "no margins" complaint):** containers get
  `_width: 100%` + `_widthMax: <grid>` — NEVER a fixed `_width`. Every
  section carries side padding (60px desktop) as the sub-max-width gutter
  backstop; grid math: max-width 1300 @1440 comp ≈ 70px gutters, padding
  keeps ≥60px below 1300. Full-bleed children (stats bars, edge-bleed
  images) use `margin-right: calc((100vw - 100%)/-2)` + `overflow:hidden`
  on the section (100vw includes the scrollbar). Verify gutters at
  1280 / 1440 / 1920 — a desktop comp width is one sample of a range;
  fixed widths fail invisibly below the container max.
- **Grids use `repeat(N, minmax(0, Wpx))`, never fixed column widths** —
  fixed comp-width columns overflow below the comp width.
- **Containing-block check before absolute positioning:** hero recipes set
  `position:relative` on the CONTAINER (for z-index layering), so
  `absolute` children resolve against it, not the section — offsets then
  double-count section padding. Locate the actual positioned ancestor
  first; express offsets container-relative; re-probe after first paint.
- **Flex rows that ignore `justify-content: space-between`:** check the
  PARENT's `align-items` — a column-flex parent with `flex-start` shrink-
  wraps each row to content width and space-between has nothing to
  distribute (observed on a pilot-build footer). Fix the parent (`stretch`), not the row.
- Element/page CSS loads AFTER plugin tokens.css. tokens rules need
  `!important` to beat later element rules; an element's own `!important`
  ties and wins by load order — fix those at source.
- Element-level settings emit as `#brxe-id` rules (specificity 1-0-0) and
  silently beat global-class `:hover` rules (0-2-0). Variant styling that
  will ever need states belongs in a GLOBAL class (`_cssGlobalClasses`,
  by class ID) with the element's inline styles removed (set keys to
  null) — never inline on the element.
- **Cross-element overrides lose same-specificity ties by document
  order.** Any rule in element A's CSS targeting element B must carry a
  `#brx-content` / `#brx-header` / `#brx-footer` prefix to win. A
  `#brxe-B{...}` rule written in A's CSS loses if A appears earlier in
  the tree. (A live example of this failing silently: a header-CSS
  `.brxe-text-link` rule at 0-1-1-0 beats a plain `#brxe-X`, so the
  override needed the two-id selector `#brxe-PARENT #brxe-X`.)
- tokens type-scale utility classes carry `!important`, so they are CAPS:
  an element wearing `.lc-section-h2` (38px) cannot render a
  design-specified 45px. For an intentional per-design deviation, OMIT the
  class and set the element's typography explicitly — the deviation is
  opting OUT of the class, not fighting it.
- Full-bleed wider than container: add `max-width: none` or the calc
  width silently caps at 100%.
- `%root%` in `_cssCustom` saved via MCP emits LITERALLY (dead CSS) —
  always write literal `#brxe-<id>` selectors.
- **Escaped unicode in CSS gets mangled through the JSON save path** —
  write the LITERAL character (`✓`, `→`), never `\2713` / `\2192`.
- `_background` images need `{id, url}` — id alone persists but emits no
  CSS. `_cssGlobalClasses` takes class IDs (e.g. "ujrjee"), never names.
- **Element CSS is NOT emitted parent-before-child.** A child container's
  `_cssCustom` lands at an EARLIER byte offset than its parent's, so at
  equal specificity the PARENT wins on source order — the DOM intuition is
  backwards. Never rely on position between two elements' blocks; raise
  specificity or add `!important` (after checking the competing declaration
  isn't itself `!important`). The upside: parking an override in an UNUSED
  `_cssCustom` field on a nearby element beats splicing a 10KB block.
- **A component-named utility class must fully declare its identity** —
  family, weight, size, colour — not just the one property that differed
  from its first container. `.lc-arrow-link` declared only
  `font-weight:500` and rendered in THREE typefaces across six uses, read
  as random per-page inconsistency for a whole QA round. Modifier-named
  classes (`.lc-eyebrow--dark`, colour only) are the exception. Audit:
  "dropped in a container with no typography, does it still look right?"
- **Global classes compile to `.class.brxe-<elementtype>`**
  (`.lc-btn.brxe-button`), so they CANNOT style raw HTML typed into a
  text/rich-text field — that markup carries no `brxe-*` class, and
  promoting a hand-written class silently unstyles every consumer while
  looking like it "didn't take". Confirm the carriers are real Bricks
  elements first (wrapper+inherit fallback: `reference/recipes.md`), and
  when the purpose is "the client's team can edit this", PROVE propagation
  live — set a wrong value, confirm every consumer moves, revert.
- Site utility classes (`.lc-pattern-corner`) are usually plain `_cssClasses`
  strings, NOT registered global classes (`global_class list` returns
  nothing) — removing one means rewriting that string, not calling the
  global-class remove action.
- **`_typography.font-family` is family-only.** Bricks emits one quoted
  family, so `brand-grotesk, sans-serif` becomes the invalid family
  `"brand-grotesk, sans-serif"` — a client declaration carrying a fallback
  stack survives only in handwritten `_cssCustom`. A new Adobe kit font is
  absent from Bricks' font picker (that cache refreshes only when the
  project ID is re-saved) yet renders fine: a missing picker entry is not a
  broken kit.
- **Never wire anything to a token without a pre-flight** on the GENERATED
  stylesheet — global variables AND typography-scale variables written
  through the MCP emit doubled (`----lc-navy`, `----lc-text-h1`), so `var(--lc-navy)` resolves
  empty (the scale's own utility classes included) and the MCP can repair
  neither. Only palette colours emit clean vars via MCP: type sizes go in
  literal px, other non-colour tokens in a plugin-enqueued `:root{}` (the
  lc-core site config). Probe each path separately — one clean path proves
  nothing about its siblings. `var()` works in the font-size and colour
  fields but NOT font-family. Procedure: `reference/recipes.md`.
- **`overflow:hidden` on a section is for containing a positioned or
  full-bleed CHILD, never for a background** — backgrounds paint inside the
  border box and cannot overflow. Added reflexively beside a gradient it
  clipped a card whose `margin-bottom:-70px` WAS the designed overlap
  ("the box disappeared"), geometry still measuring correct because only
  paint was cut. Scan descendants for negative margins, absolute
  positioning outside the padding box, and transforms first; for horizontal
  containment use `overflow-x: clip` (permits `overflow-y: visible`) —
  `overflow: hidden` forces the other axis to `auto`.
- **Cross-card alignment is a subgrid problem, not a `min-height`
  problem** — row heights must derive from the tallest card, not hard-code
  today's copy; a `min-height` found in existing work is a dated
  measurement, treat it as debt. Recipe plus the `row-gap` inheritance
  trap: `reference/recipes.md`.

## 8. Verification recipe (run before "done")

Moved to `reference/verification.md` — read after any structural edit and before declaring any change or PAGE done (it ends by calling §11 and §12).

## 9. WP-admin automation + release hygiene

Moved to `reference/release-checklist.md` — read before any plugin deploy, new-site MCP onboarding, staging→production promotion, shared-site state flip, or declaring a SESSION complete.

## 10. Raw HTML is sanitized at SAVE time (wp_kses) — read back first

Raw HTML in text-basic elements can be run through `wp_kses_post` AT SAVE
TIME: `<iframe>` is always stripped and `<input>` is stripped. The stored
settings are already mutilated — re-rendering can't recover what save
discarded.

**Sanitization is FORMAT-dependent on the bricks-mcp save path:** the
SIMPLIFIED-format path is kses'd; flat-format and `element:update` writes
are not. Treat that as an implementation detail, not a guarantee — the
read-back habit stays mandatory on every path.

- Video embeds: use the native Bricks `video` element
  (`{videoType:"youtube", youTubeId}`) and set `{controls:true}` — Bricks
  defaults to `controls=0`.
- CSS-only form-control patterns (radio tabs etc.): the site core plugin's
  kses module (e.g. lc-core's `inc/kses.php`) allowlists
  `input`/`label[for]` via a `wp_kses_allowed_html` filter — verify the
  tags survived by grepping the RENDERED page right after save.
- If a needed tag isn't allowlisted, extend the core plugin's kses module
  (`inc/kses.php`); never hand-encode workarounds.
- **`<details>`/`<summary>` survive kses** — they are the JS-free primitive
  for accordions, FAQs and mobile menus (§10.5).
- Principle: sanitizers mutate at write time — always read back what SAVED
  before styling or building on top of pushed markup.
- Toggle switches: `<input type="checkbox">` + `<label for>` survives the
  save path and needs ZERO JS for its visuals (recipe in
  `reference/recipes.md`) — ship the presentation now, persistence is its
  own, possibly gated, step.
- **Every JS-adding surface can be classifier-blocked** in a
  default-permission session: `code:set_page_scripts` (Dangerous Actions
  off), the dangerous-actions toggle itself, AND the Chrome fallback, which
  holds for REST content writes but does NOT extend to script injection.
  Working pattern — build everything except the script, stage the exact
  script and the exact MCP call in a project file, and hand the user the
  30-second toggle; `set_page_scripts` then succeeds via MCP with no
  browser at all. Page CSS writes are gated the same way, but element-level
  `_cssCustom` stays writable — solve there rather than asking the client
  to paste code.
- When a build introduces a plugin-backed shortcode or dynamic module,
  record in the build notes (a) the file and function that DEFINE it,
  (b) which layer owns each aspect — markup/logic in PHP, presentation in
  the element CSS, content in taxonomy terms or fields — and (c) whether
  that file has a LOCAL VERSIONED copy; if not, pull one down before the
  first edit. A per-site config that is gitignored and ships only inside
  the deploy zip exists only on the server: wp-admin editor changes are
  unversioned and the next deploy destroys them.

## 10.5 Interactions + animations (Bricks-native)

Moved to `reference/interactions.md` — read before adding any interaction, scroll reveal, animation, or JS-free menu/toggle.

## 11. Design Fidelity Pass (comp-diff — run per page before "done")

Moved to `reference/fidelity-pass.md` — read before declaring any PAGE done, and again before every design-fix round.

## 12. Responsive passes

Moved to `reference/responsive-pass.md` — read before declaring any PAGE done.

## Pre-flight (enforcement)

Before delivering any Bricks change, re-read sections 1, 3, 4, 7 and 8 and
confirm each applied edit passed the verification recipe. Before declaring
a PAGE built or a design-fix round complete, additionally run §11 against
the page's PDF band set and §12's probes at all three widths. Before
declaring a SESSION complete, run §9's push check in every touched repo.
If any check was skipped, run it now — a 30-second curl beats a client QA
round.
