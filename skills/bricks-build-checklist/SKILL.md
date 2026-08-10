---
name: bricks-build-checklist
description: Build + verification checklist for WordPress sites built with Bricks Builder via the bricks-mcp connector. Use whenever composing or editing Bricks pages/templates through MCP tools — page builds, section edits, template migrations, global CSS changes, image/tile work, query loops, responsive passes — and before declaring any Bricks change "done". Codifies hard-won gotchas so client QA rounds don't re-discover them.
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

Connection guard: before ANY write, `get_site_info` and confirm the site
name matches the project. A generically-named MCP server can point at a
different client's site — a passed guard is the only proof you're writing
to the right install.

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

Templatization rule: only sections with EXACTLY identical content get a
shared global section template. Near-duplicates (same layout, drifted
copy) go to the client as a copy-standardization decision first —
silently unifying copy destroys intentional per-page variations.

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
- **Precondition on that rule:** crop-as-displayed is valid only when
  NOTHING ELSE is composited over the crop region. Check the region
  against the comp for overlapping text, badges or scrims first — the
  node export bakes those in too. If anything overlaps, extract the
  embedded source object instead and solve its opacity/blend separately
  (per-channel alpha: channels agreeing = alpha overlay, channels
  disagreeing = multiply). Verify every extracted asset **in isolation**
  before upload, not only composited in place.
- **Icon slots — `rawImages` vs `export`:** on a Figma icon rect, the
  connector's `rawImages` are the designer's uploaded source fills (full
  alpha); the node `export` BAKES the white rounded-rect card behind the
  fill. For transparent icon slots always take `rawImages`. (Responses
  may mis-label the mime as jpeg — verify the stored file is real RGBA.)
- Figma vector/frame exports bake context rects (node-bounds + parent
  fills) into "transparent" exports. Fix = SVG export + strip injected
  `<rect>`s, or flood-fill border-connected white — but restore
  legitimate white regions (photo frames) by re-opaquing pixels inside
  known photo rects. Verify white/light assets against a DARK backdrop;
  alpha-ratio checks composited on white prove nothing.
- Asset sourcing: when Figma exports come back low-res or an asset is
  missing, run `pdfimages -png` on the client's full-page PDF before
  asking the client — placed images extract at their PLACED resolution
  (RGB layer + a separate L-channel SMask = the alpha; recompose with
  PIL `putalpha`). Check the extracted dimensions, since a PDF can embed
  a low-res original.

## 3. `background` shorthand must include a color

A `background:` shorthand with no color layer resets `background-color`
to transparent. Bricks lazy-load strips background-images until scroll, so
such sections flash WHITE. Automation browsers never fire the lazy
IntersectionObserver — trust computed `background-color`, not `bgImage`,
when probing. Rule: every section background written as shorthand gets a
separate `background-color: <band color>` line.

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
  `#brxe-{id}` CSS for that element. For anchor targets, add a zero-height
  child `div` carrying the id instead of touching the section's own id.
- Element ids: exactly 6 lowercase alphanumerics; root parent must be
  integer `0` (string "0" rejected at root).
- `element remove` does NOT cascade — orphaned children STILL RENDER.
  Remove every descendant id individually, then curl-verify zero orphans
  (`verify:orphaned_css` scans stored CSS surfaces for dead `#brxe-` refs).
- Retroactivity (twice-learned, cf. rule 2's bake-don't-crop sweep): after
  codifying any trap like the anchor-id one above, sweep the EXISTING build
  for pre-rule violations — pages built before the additive-div convention
  still carry anchor ids set directly on sections and orphan their CSS (run
  rule 8's orphaned-rule scan on them).

## 7. CSS layering + layout facts

**Selector choice — Bricks' targeting is asymmetric.** Settle which case
you're in with one probe (`getElementById('brxe-X')?.className`):

| Element kind | Correct selector | Why |
|---|---|---|
| Static element | `#brxe-X` | it has the DOM id but NOT a `brxe-X` class |
| Loop child | `.brxe-X` | it has the class but an EMPTY id |
| Bare (unlinked) image | `#brxe-X, #brxe-X img` | the element IS the `img` node |

Never write `#brxe-X img` alone for a bare image — there is no inner img.

- Dead paths that emit NOTHING: theme-style `general.containerWidth`,
  `css.custom`, `h1Typography`-style heading sub-keys, Bricks
  global_variable entries (they're stored as AI-reference tokens only —
  use literal hex in element CSS). Trusted paths: plugin-enqueued
  tokens.css, element-level settings/`_cssCustom`, element
  `_typography:<breakpoint>`.
- **Flex key is `_direction`, NOT `_flexDirection`** — the wrong key
  silently no-ops.
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

## 8. Verification recipe (run before "done")

1. Curl every touched page with `?nc=$RANDOM` (page caches lie; browsers
   show stale element CSS).
2. Section-order assert (rule 1) per page, per render mode.
3. Overflow scan at desktop + narrow simulation (exclude
   `#claude-phantom-*`, `#wpadminbar`, and `position:fixed` elements):
   `getBoundingClientRect().right > clientWidth` count must be 0 — and
   `document.documentElement.scrollWidth === clientWidth` (intentional
   full-bleed elements may report rects past the edge while clipped).
4. Computed-style probes for backgrounds (rule 3) — not screenshots;
   below-fold sections and `_cssCustom` bg-images render blank in
   automation screenshots even when correct.
5. Anchor-id integrity: for every section whose rendered id is NOT
   `brxe-`-prefixed (it carries an `_attributes` anchor id, cf. rule 6),
   assert its background/padding still computes as intended — OR run
   `verify:orphaned_css`. Fix = dual selector or migrate the id to an
   additive zero-height child div.
6. If a conditional mode exists (alert vs normal), fire-drill BOTH
   directions and re-run the asserts in each.
7. Screenshot only for above-fold composition; use `zoom` region captures
   for detail claims.
8. **Environment limits** — know these before calling something broken:
   - Time- and viewport-driven behavior (enterView reveals, lazy-load,
     CSS animations) CANNOT be verified in the automation pane (frozen
     rendering clock — `getAnimations()[0].currentTime` stays 0,
     IntersectionObserver never delivers) nor in background Chrome tabs
     (`document.visibilityState === "hidden"`). Probe the clock before
     debugging "broken" observers.
   - Bricks lazy-hidden also suppresses `_cssCustom` background-images,
     not just `_background` ones — verify via emitted CSS + the bg-color
     fallback, never via a pane screenshot.
   - Blank images in pane screenshots must be cross-checked with
     `img.complete` / `naturalWidth` before being treated as defects
     (pane paint-lag).
   - Fresh pane tabs open at a NARROW default viewport, so mobile rules
     are active — `resize_window` to 1440 before trusting computed probes.
   - Below-fold visual checks in the pane: keep scrollY 0 and shift
     content with `document.body.style.transform = 'translateY(-Npx)'` —
     real scrolling renders with a wrong-sign offset there.
   - `getComputedStyle` during a transition's DELAY returns the START
     value. To assert a target state, inject `transition:none!important`
     first — otherwise a correct rule reads as "selector didn't match".
   Verify instead: assert emitted config/CSS statically, design fallbacks
   that fail visible (§10.5), and get a human glance for final motion QA.
9. Run the §11 fidelity pass before declaring a PAGE done.
10. Run the §12 responsive probes before declaring a PAGE done.

## 9. WP-admin automation + release hygiene

- Synthetic clicks on wp-admin upload/update screens stall — fall back to
  `HTMLFormElement.prototype.submit.call(form)` (an input named "submit"
  shadows the method) and JS `element.click()` on nonce links.
- **Plugin deploy without user presence (preferred recipe):** REST-stage
  the zip into the site's own media library → on the wp-admin plugin
  upload page, `fetch()` it back → `DataTransfer` → `input.files` →
  submit → "Replace current with uploaded" → hit any admin page so
  `admin_init` fires the upgrade hook → delete the staged media. This
  works in the user's logged-in Chrome with no user action, and avoids
  the browser `file_upload` limitation (it only accepts session-attached
  files).
- Legacy path: build zip OUTSIDE mounted folders (mounts block
  overwrite), copy under a NEW filename, wait ~60s for cloud sync before
  browser file_upload.
- Version bumps: WP shows the plugin HEADER version, code gates on the
  define — bump BOTH.
- **Release artifacts are scanned, not assumed.** A zip built from a
  working tree inherits UNTRACKED per-site files (site configs,
  client-specific data). Build public releases from a clean checkout, or
  move per-site files aside first — then content-scan the BUILT ARTIFACT
  for client identifiers before publishing. Scanning the tree is not
  scanning the artifact.
- **End every plugin session with a push check:** run
  `git log --branches --not --remotes --oneline` in each touched repo
  (site core plugin, connector) and push anything unpushed. Work that exists
  only in a local commit is work the next session cannot see.
- Flipping shared-site state (e.g. a conditional render mode) requires
  explicit user
  approval first; plan the revert before the flip.
- If the site has a confirm() guard on state-flip forms (some site plugins add one),
  automation must run `window.confirm = () => true` before submitting.
- Some connector actions are gated behind a "Dangerous Actions" toggle
  (page CSS/scripts writes). When it's off, element-level `_cssCustom` is
  still writable — prefer solving in element CSS over asking the client
  to paste code.

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

## 10.5 Interactions + animations (Bricks-native)

- Use `_interactions` arrays (never deprecated `_animation*` keys):
  `{id: <6-char>, trigger: "enterView", action: "startAnimation",
  animationType: "fadeInUp", animationDuration: "0.7s", animationDelay:
  "0.1s", target: "self", runOnce: true}` — `runOnce` persists as `"1"`,
  accepted. Stagger siblings by 0.1s; keep ≤5–6 animated elements per
  viewport; NEVER animate the hero/LCP element.
- Bricks pre-hides "In"-animation elements server-side via
  `data-interaction-hidden-on-load` + the layered rule
  `.bricks-is-frontend :not(.brx-animated)[data-interaction-hidden-on-load]
  {opacity:0}` (animate-layer.min.css, `@layer bricks`).
  `bricks-lazy-hidden` only suppresses `background-image` — it is NOT the
  opacity mechanism.
- MANDATORY with any enterView reveal — the dead-observer safety net
  (un-layered, site-wide CSS): content hidden until JS+observer succeed
  must fail VISIBLE:
  ```css
  @keyframes lcReveal{to{opacity:1}}
  :not(.brx-animated)[data-interaction-hidden-on-load]{animation:lcReveal .6s ease 3s forwards}
  ```
  Un-layered animations beat layered static opacity; once Bricks adds
  `.brx-animated` the selector stops matching and the designed animation
  takes over.

### Scroll-driven state without JS — `.brx-animated`

An `enterView` interaction makes Bricks add `.brx-animated` to that
element the moment it enters the viewport, and **never removes it** (the
`animationend` handler strips only `brx-animate-<type>`). That is a free,
permanent "this has scrolled into view" hook — reach for it before writing
any IntersectionObserver JS, especially where page-level script fields are
gated behind Dangerous Actions.

```css
#brxe-ID::before{ /* idle state */ transition:<props> calc(var(--d) + .55s); }
#brxe-ID.brx-animated::before{ /* revealed state */ }
```

- Specificity: `#brxe-ID.brx-animated` (1-1-0) beats the `#brxe-ID` base
  rule (1-0-0). No `!important` needed.
- **The delay must exceed the card's own reveal.** A pseudo-element
  inherits its element's reveal opacity, so with no `transition-delay` the
  new state arrives already-applied and the transition is never seen.
- Carry each row's existing `animationDelay` stagger as a `--d` custom
  property on the element (pseudo-elements inherit it) so the cascade stays
  in sync when several elements enter view at once.
- Do NOT add a dead-observer fallback for the state change. The §10.5
  safety net above fires on a 3s timer and would flip every below-fold
  element while off-screen. Degrading to "state never changes" is correct;
  degrading to "all states fire at once, unseen" is not.
- Verify per §8.8: assert both states with `transition:none!important`
  injected; the scroll trigger itself is not observable in the pane.

### Kses-safe, JS-free mobile menu

When no real JS nav element is available via MCP, the standard recipe is a
`<details class="…">` burger in a text-basic element plus `:has()` to
reveal the EXISTING nav container as a fixed overlay:

```css
#brx-header:has(.lc-mmenu[open]) #brxe-NAV{opacity:1;visibility:visible}
html:has(.lc-mmenu[open]){overflow:hidden}  /* scroll lock */
```

The text-basic WRAPPER div nests `<details>` one level down, which breaks
sibling-combinator tricks — `:has()` is the load-bearing selector here, not
a convenience. Style `summary` with `list-style:none` +
`::-webkit-details-marker{display:none}` and morph it to an X on `[open]`.

- Hover system: put states on classes (see §7 specificity note); include
  `:active` press states, `a:focus-visible` outlines, and a
  `@media (prefers-reduced-motion: reduce)` kill-switch in the same block.
- Bricks click-interaction semantics (verified against bricks.min.js):
  hide = inline `display:none`; show = clear inline, then if the computed
  value is still none, set `display:BLOCK` (so panels must look right
  under block flow); `setAttribute`/`removeAttribute` with
  `actionAttributeKey:"class"` = `classList` add/remove (modifier-safe);
  `targetSelector` = `querySelectorAll` (ALL matches).
- Div-based tab rows driven by click interactions have NO keyboard access
  or ARIA — that is an accessibility debt to log, not a shipped feature.
- Site-wide interaction CSS rides in the HEADER template's `_cssCustom`
  until an enqueued stylesheet path exists — it renders on every page.

## 11. Design Fidelity Pass (comp-diff — run per page before "done")

The verification recipe (§8) checks the build against itself; this pass
checks it against the DESIGN. Skipping it is how a structurally-perfect
page ships with the wrong scrim, wrong icon fills, missing decorative
layers, and a stretched button (a pilot build's homepage, round 1).

**Ground truth priority:**
1. **`get_design_context` on the node** (Figma Dev Mode) — returns the
   DECLARED typography, geometry and copy verbatim. It is the authority
   for font family/weight/size disputes; never adjudicate weights from
   raster crops. Note it often SUCCEEDS on full frames whose
   `get_metadata` times out — try the full-frame call before falling back.
2. **The client's per-page PDF export** — the frozen, deterministic record
   and the source for photo extraction at placed resolution. Live Figma
   files drift after approval (observed on a pilot build same-day).
3. Figma metadata numbers alone carry no scrims, baked fills, or
   decorative layers — never sufficient on their own.

1. Render the PDF once: `pdftoppm -png -r 100 <page.pdf>` → slice into
   ~1500px section bands (PIL). Keep the bands; they're the reference for
   every later edit to that page. For asset extraction prefer REGION crops
   (`pdftoppm -x -y -W -H`) + channel math over full-page renders and
   per-pixel PIL loops. `-r 144` = 2x native for images placed at 144ppi.
2. Per section, side-by-side against the live render, check:
   - [ ] **Geometry:** content gutters/max-width at 1280 / 1440 / 1920
         (§7 container discipline); full-bleed edges reach the viewport.
   - [ ] **Overlay/scrim tone:** sample a known-white and a known-dark
         pixel in the comp; reverse-engineer the blend — per-channel
         `alpha = (bg − target)/(bg − raw)` for alpha overlays; if
         channels disagree wildly, it's a multiply blend
         (`mix-blend-mode:multiply` + solid gradient). Encode literal hex.
   - [ ] **Accent colors + case:** icon circle fills, eyebrows, tags,
         link colors against palette tokens — including text-transform
         (comp "Primary" ≠ built "PRIMARY") and font family/weight.
   - [ ] **Decorative layers PRESENT:** pattern bands, connector rails,
         dots/checks, badges, divider strips, accent lines. These live in
         page-level vectors the section inventory misses — walk the comp
         band visually and name every non-photo layer.
   - [ ] **Typography rhythm:** display line-height (comps run ~1.1, Bricks
         default 1.4 — measure line spacing off the band), intentional
         line breaks, heading widths.
   - [ ] **Assets as displayed:** every image compared against the comp's
         crop/tint — raw-source montages and baked-bounds exports jump out
         here (§2 displayed-node rule).
3. **Calibrate before trusting any comp-derived measurement.** Solve an
   element already BUILT AND APPROVED and confirm your method returns its
   known value. Compare ink-to-ink
   (`actualBoundingBoxLeft/Right`), never ink-to-advance; measure cap
   height off a flat-topped capital only. Where the comp font and the
   shipped font differ, the substitution is a known fidelity CEILING —
   record it and put the residual on the punch-list instead of chasing it.
4. **A spec measured on a sample of comps is a HYPOTHESIS for the rest.**
   Before batch-applying a type rule to page N, verify N's declared value
   (`get_design_context`) or its PDF. Distinguish component VARIANTS
   (left-aligned section H2 vs centered display header) before unifying
   sizes — "one size everywhere" sweeps have been wrong twice.
5. **Audit which font weights the kit actually serves.** A declared weight
   the kit doesn't ship renders silently ONE WEIGHT DOWN, site-wide, from
   day one. Fetch the kit CSS (e.g. `use.typekit.net/<id>.css`), parse
   `@font-face`, and confirm every weight in use is present. Beware
   near-miss family names — a base family may ship only display weights
   while the usable upright range lives under a `-pro` sibling.
6. Anything intentionally divergent goes on the client punch-list — a
   deviation is a decision, never a silent default.
7. Assets needed during the pass come from the SAME PDF: `pdfimages -png`
   emits RGB + SMask pairs (recompose for alpha) at placed resolution.

## 12. Responsive passes

Bricks-native breakpoints are **991 / 767 / 478**. Breakpoint-suffixed
element settings (`_padding:tablet_portrait`, `_typography:mobile_landscape`)
emit at exactly those widths and compose cleanly with handwritten
`@media` blocks.

Three landmines on every row→column flip:
1. **Shrink-wrap** — the flipped container needs `align-items: stretch`.
2. **Residual margins** — children keep their desktop `margin-left` and
   overflow by exactly that amount. Every stacked-children rule needs
   `width:100%; max-width:100%; min-width:0; margin-left:0; margin-right:0`.
3. **Same-specificity ties** — all cross-element overrides carry a
   `#brx-content` / `#brx-header` / `#brx-footer` prefix (§7).

Conventions:
- Each page gets ONE carrier element whose `_cssCustom` holds that page's
  responsive block; site-wide framework rules live in the header template.
- Never leave an interim `!important` mobile block in place once the
  designed pass lands — replace it, don't layer on it.
- Sweep the 768px TABLET range explicitly. Mobile-only fixes written at
  ≤767 leave a gap at 768–991 that no phone check catches.
- Wide content (matrices, tables) gets an `overflow-x` scroller plus a
  sticky first column and a visible swipe affordance.
- Probe `scrollWidth === clientWidth` + the per-element right-edge scan
  (position:fixed excluded) at **375 / 768 / 1440** per page before "done".

## Pre-flight (enforcement)

Before delivering any Bricks change, re-read sections 1, 3, 4, 7 and 8 and
confirm each applied edit passed the verification recipe. Before declaring
a PAGE built or a design-fix round complete, additionally run §11 against
the page's PDF band set and §12's probes at all three widths. Before
declaring a SESSION complete, run §9's push check in every touched repo.
If any check was skipped, run it now — a 30-second curl beats a client QA
round.
