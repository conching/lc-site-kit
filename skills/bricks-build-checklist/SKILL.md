---
name: bricks-build-checklist
description: Build + verification checklist for WordPress sites built with Bricks Builder via the bricks-mcp connector. Use whenever composing or editing Bricks pages/templates through MCP tools — page builds, section edits, template migrations, global CSS changes, image/tile work, query loops — and before declaring any Bricks change "done". Codifies hard-won gotchas so client QA rounds don't re-discover them.
---

# Bricks Build Checklist (internal)

Internal skill for Library Creative WP builds using Bricks + bricks-mcp.
Born from a prior build (2026-07), hardened on a pilot build.
Three rules of thumb above all: **verify structure, not just presence**,
**verify appearance against the comp, not against your own intent** (§11),
and **new design rules apply retroactively to code written before the rule
existed.**

Connection guard: before ANY write, `get_site_info` and confirm the site
name matches the project. A generically-named MCP server can point at a
different client's site — a passed guard is the only proof you're writing
to the right install.

## 1. After ANY structural edit: assert section ORDER, not presence

`element add` with name `template` APPENDS at root regardless of the
`position` param — root-level TEMPLATE elements always land at root. Plain
element adds are less predictable and the behavior conflicts by context: a
subagent reported `element add` "ignores parent/position (lands at root)"
and that `move` can't re-parent, yet same-day main-thread adds DID honor
`parent_id`/`position` (footer HCF block children and urgent-loop children
rendered correctly nested). Record both behaviors with their conditions
rather than trusting a blanket rule, and after ANY add verify the rendered
parent chain by curl, not just presence — a presence check
(`grep -c id="brxe-X"`) passes while the page renders in the wrong order or
at the wrong nesting level; clients catch this, you should first. If an add
lands at root unexpectedly, re-parenting requires a full-page
`update_content` (`element move` only repositions WITHIN a parent, it
cannot re-parent) — but do NOT preemptively switch to `update_content`;
adds usually nest fine.

After template insertion, section removal, or any root-level change, curl
the page with a cache-buster and assert the FULL top-level sequence:

```bash
curl -s "https://SITE/PAGE/?nc=$RANDOM" | grep -oE 'id="brxe-(sec1|sec2|sec3|...)"'
```

Compare against the intended order for EVERY page touched — and for every
render mode if the site has conditional stacks (e.g. conditional render
modes such as alert vs normal). Fix with `element move` (position = index
after removal from the array).

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
- **Displayed-node rule (observed on a pilot-build card):** when the comp
  shows a CROP or styled variant of a source image (Figma crop transform,
  baked tint, ghost overlay), export the NODE as displayed
  (`download_assets` on the node, 2x) — never place the raw fill. A raw fill
  is only correct when the comp places it uncropped and unstyled. Symptom of
  getting this wrong: "why is there a collage here?" — the raw source was a
  montage the design only sampled.
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
  vanish otherwise.
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
  `.brxe-<elementid>`, never `#brxe-<elementid>`.
- Bricks query objects need snake_case WP_Query keys (`post_type`,
  `posts_per_page`); camelCase silently returns zero items.
- To give a purpose-built loop a meta/tax constraint, put it NATIVELY in
  the element's own query settings (`query.meta_query =
  [{id,key,value,compare}]` + `meta_query_relation`) — it works
  immediately. Reserve the `bricks/posts/query_vars` hook for AUGMENTING
  existing loops from GET params: lc-core hooked query_vars to inject a
  meta_query into a newly-created loop (keyed first on `_cssClasses`, then
  on element id) and it demonstrably ran for the pre-existing main loop but
  never affected the new loop — zero items under both keying schemes. A
  constraint that belongs to ONE specific loop is safer declared in that
  loop's own settings than injected imperatively by a hook.
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
  Remove every descendant id individually, then curl-verify zero orphans.
- Retroactivity (twice-learned, cf. rule 2's bake-don't-crop sweep): after
  codifying any trap like the anchor-id one above, sweep the EXISTING build
  for pre-rule violations — pages built before the additive-div convention
  still carry anchor ids set directly on sections and orphan their CSS (run
  rule 8's orphaned-rule scan on them).

## 7. CSS layering + layout facts

- Dead paths that emit NOTHING: theme-style `general.containerWidth`,
  `css.custom`, `h1Typography`-style heading sub-keys, Bricks
  global_variable entries (they're stored as AI-reference tokens only —
  use literal hex in element CSS). Trusted paths: plugin-enqueued
  tokens.css, element-level settings/`_cssCustom`, element
  `_typography:mobile_*`.
- **Container discipline (a pilot build's "no margins" complaint):**
  containers get `_width: 100%` + `_widthMax: <grid>` — NEVER a fixed
  `_width`. Every section carries side padding (60px desktop) as the
  sub-max-width gutter backstop; grid math: max-width 1300 @1440 comp ≈ 70px
  gutters, padding keeps ≥60px below 1300. Full-bleed children (stats bars,
  edge-bleed images) use `margin-right: calc((100vw - 100%)/-2)` +
  `overflow:hidden` on the section (100vw includes the scrollbar). Verify
  gutters at 1280 / 1440 / 1920 — a desktop comp width is one sample of a
  range; fixed widths fail invisibly below the container max.
- **Containing-block check before absolute positioning:** hero recipes set
  `position:relative` on the CONTAINER (for z-index layering), so
  `absolute` children resolve against it, not the section — offsets then
  double-count section padding. Locate the actual positioned ancestor
  first; express offsets container-relative; re-probe after first paint.
- **Flex rows that ignore `justify-content: space-between`:** check the
  PARENT's `align-items` — a column-flex parent with `flex-start` shrink-
  wraps each row to content width and space-between has nothing to
  distribute (observed on a pilot-build footer). Fix the parent
  (`stretch`), not the row.
- Element/page CSS loads AFTER plugin tokens.css. tokens rules need
  `!important` to beat later element rules; an element's own `!important`
  ties and wins by load order — fix those at source.
- Element-level settings emit as `#brxe-id` rules (specificity 1-0-0) and
  silently beat global-class `:hover` rules (0-2-0). Variant styling that
  will ever need states belongs in a GLOBAL class (`_cssGlobalClasses`,
  by class ID) with the element's inline styles removed (set keys to
  null) — never inline on the element.
- tokens type-scale utility classes carry `!important`, so they are CAPS:
  an element wearing `.lc-section-h2` (38px) cannot render a
  design-specified 45px. For an intentional per-design deviation, OMIT the
  class and set the element's typography explicitly — the deviation is
  opting OUT of the class, not fighting it.
- Full-bleed wider than container: add `max-width: none` or the calc
  width silently caps at 100%.
- Bare (unlinked) Bricks images render as bare `<img>` — style
  `#brxe-X` directly; `_width` doesn't size them. Use dual selector
  `#brxe-X, #brxe-X img` to cover both linked/unlinked cases.
- `%root%` in `_cssCustom` saved via MCP emits LITERALLY (dead CSS) —
  always write literal `#brxe-<id>` selectors.
- `_background` images need `{id, url}` — id alone persists but emits no
  CSS. `_cssGlobalClasses` takes class IDs (e.g. "ujrjee"), never names.

## 8. Verification recipe (run before "done")

1. Curl every touched page with `?nc=$RANDOM` (page caches lie; browsers
   show stale element CSS).
2. Section-order assert (rule 1) per page, per render mode.
3. Overflow scan at desktop + narrow simulation (exclude
   `#claude-phantom-*` and `#wpadminbar`):
   `getBoundingClientRect().right > clientWidth` count must be 0 — and
   `document.documentElement.scrollWidth === clientWidth` (intentional
   full-bleed elements may report rects past the edge while clipped).
4. Computed-style probes for backgrounds (rule 3) — not screenshots;
   below-fold sections and `_cssCustom` bg-images render blank in
   automation screenshots even when correct.
5. Anchor-id integrity: for every section whose rendered id is NOT
   `brxe-`-prefixed (it carries an `_attributes` anchor id, cf. rule 6),
   assert its background/padding still computes as intended — OR scan page
   CSS for `#brxe-<elementid>` rules that match nothing in the DOM
   (orphaned-rule scan). Fix = dual selector or migrate the id to an
   additive zero-height child div.
6. If a conditional mode exists (conditional render modes, e.g. alert vs
   normal), fire-drill BOTH directions and re-run the asserts in each.
7. Screenshot only for above-fold composition; use `zoom` region captures
   for detail claims.
8. **Environment limits:** time- and viewport-driven behavior (enterView
   reveals, lazy-load, CSS animations) CANNOT be verified in the
   automation pane (frozen rendering clock — `getAnimations()[0]
   .currentTime` stays 0, IntersectionObserver never delivers) nor in
   background Chrome tabs (`document.visibilityState === "hidden"`).
   Before debugging "broken" observers, probe the clock. Verify instead:
   assert emitted config/CSS statically, design fallbacks that fail
   visible (§10.5), and get a human glance for final motion QA.
   Below-fold visual checks in the pane: keep scrollY 0 and shift content
   with `document.body.style.transform = 'translateY(-Npx)'` — real
   scrolling renders with a wrong-sign offset there.
9. Run the §11 fidelity pass before declaring a PAGE done.

## 9. WP-admin automation fallbacks

- Synthetic clicks on wp-admin upload/update screens stall — fall back to
  `HTMLFormElement.prototype.submit.call(form)` (an input named "submit"
  shadows the method) and JS `element.click()` on nonce links.
- Plugin deploy: build zip OUTSIDE mounted folders (mounts block
  overwrite), copy under a NEW filename, wait ~60s for cloud sync before
  browser file_upload.
- Version bumps: WP shows the plugin HEADER version, code gates on the
  define — bump BOTH.
- Flipping shared-site state (e.g. a conditional render mode) requires
  explicit user approval first; plan the revert before the flip.
- If the site has a confirm() guard on state-flip forms (some site plugins
  add one), automation must run `window.confirm = () => true` before
  submitting.

## 10. Raw HTML is sanitized at SAVE time (wp_kses) — read back first

Raw HTML in text-basic elements saved via the app-password REST path runs
through `wp_kses_post` AT SAVE TIME: `<iframe>` is always stripped and
`<input>` is stripped. The stored settings are already mutilated —
re-rendering can't recover what save discarded.

- Video embeds: use the native Bricks `video` element
  (`{videoType:"youtube", youTubeId}`) and set `{controls:true}` — Bricks
  defaults to `controls=0`.
- CSS-only form-control patterns (radio tabs etc.): lc-core's kses module
  allowlists `input`/`label[for]` via a `wp_kses_allowed_html` filter —
  verify the tags survived by grepping the RENDERED page right after save.
- If a needed tag isn't allowlisted, extend the core plugin's kses module
  (`inc/kses.php`); never hand-encode workarounds.
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
- Hover system: put states on classes (see §7 specificity note); include
  `:active` press states, `a:focus-visible` outlines, and a
  `@media (prefers-reduced-motion: reduce)` kill-switch in the same block.
- Site-wide interaction CSS rides in the HEADER template's `_cssCustom`
  until an enqueued stylesheet path exists — it renders on every page.

## 11. Design Fidelity Pass (comp-diff — run per page before "done")

The verification recipe (§8) checks the build against itself; this pass
checks it against the DESIGN. Skipping it is how a structurally-perfect
page ships with the wrong scrim, wrong icon fills, missing decorative
layers, and a stretched button (a pilot build's homepage, round 1).

**Ground truth = the client's per-page PDF export**, not the live Figma
file (live files drift after approval — observed on a pilot build
same-day; the PDF is the frozen, deterministic record) and not Figma
metadata (numbers don't carry scrims, baked fills, or decorative layers).

1. Render the PDF once: `pdftoppm -png -r 100 <page.pdf>` → slice into
   ~1500px section bands (PIL). Keep the bands; they're the reference for
   every later edit to that page.
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
3. Anything intentionally divergent goes on the client punch-list — a
   deviation is a decision, never a silent default.
4. Assets needed during the pass come from the SAME PDF: `pdfimages -png`
   emits RGB + SMask pairs (recompose for alpha) at placed resolution.

## Pre-flight (enforcement)

Before delivering any Bricks change, re-read sections 1, 3, 4 and 8 and
confirm each applied edit passed the verification recipe. Before declaring
a PAGE built or a design-fix round complete, additionally run §11 against
the page's PDF band set. If any check was skipped, run it now — a
30-second curl beats a client QA round.
