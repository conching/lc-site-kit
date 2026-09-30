# Recipes — assets, measurement, probes, markup

Read when a checklist line points here: an export comes back wrong, an
upload or logo band is next, a comp measurement is needed, a probe returns
a surprising negative, a section must be verified before any write, or a
markup pattern has to survive kses.

## Asset sourcing, extraction and repair (§2)

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
- **No PIL? The whole pipeline is stdlib.** (1) LOCATE — render the region
  to raw PPM (`pdftoppm` WITHOUT `-png`), parse the P6 header in ten lines,
  filter for the asset's ink hue and cluster pixel columns by x-gaps to get
  true ink bounds in points; this separates icons from adjacent text of a
  different colour. (2) EXTRACT — re-render each bbox at 8px/pt with a
  small symmetric pad. (3) ALPHA — unmultiply white analytically
  (`alpha = (255 - r) / (255 - ink_r)`, colour = the flat ink) rather than
  keying. (4) WRITE — emit RGBA PNG with `zlib` + `struct`: signature,
  IHDR (colour type 6), IDAT of scanlines each prefixed by filter byte 0,
  IEND, CRC32 per chunk. Two self-checks make it trustworthy: composite
  the result back over white and assert max channel diff ≤1, and confirm
  the solved ink colour lands exactly on a known palette token.
- **Uploads that keep their filename and alt:** connector `media sideload`
  ignores `filename` (every upload lands as `file`, `file-1`, … and only
  wp-admin can rename them) and needs a public URL (a Dropbox MCP
  `download_link` works — the connector makes exactly one GET). Where the
  site's MCP entry carries a Basic Application-Password header, the same
  header works against `POST /wp-json/wp/v2/media`, which keeps the
  filename and sets alt/title in one call; never echo the credential. Set
  alt AT UPLOAD — Bricks media carousels read each slide's aria-label from
  the attachment alt.
  Third route, when neither fits (a Dropbox temp link ends in `/file`, or
  the credential is awkward to reuse): the user's signed-in wp-admin.
  (a) Ask once whether to use their Chrome — the built-in pane is usually
  signed out. (b) Open `wp-admin/media-new.php?browser-uploader` and
  `file_upload` onto the file input: plupload uploads immediately, no
  Upload click (`input.files` then reads 0). (c) Get the id and generated
  sizes from public REST `/wp-json/wp/v2/media?search=<slug>` — the
  extension redacts the Edit link's `post=ID` query. (d) Set alt on the
  attachment edit screen by JS (`#attachment_alt` value, then click
  `#publish`) — typed input did not persist — and confirm via REST
  `alt_text`. WordPress skips the `-scaled` re-encode only for files
  ≤ 2560 px on the long edge.

## SVG uploads (§2)

With SVG Support (and its enshrined/svg-sanitize pass) enabled, every file in a
batch came back byte-different — XML declaration added, self-closing
tags expanded — yet rendered identically.

- Prepare files that survive the sanitizer: internal `<use href>` only, no
  constructs that exist only in `style` attributes.
- Gate each upload with a headless-Chrome pixel diff of the SERVED file
  against the local source (as `img` and as CSS background, 1x and 2x),
  never a byte diff, which flags every file as corrupted.
- WordPress stores SVG attachments with width/height 0 and Bricks renders
  the lazy placeholder with `viewBox 0 0 0 0`, so an SVG image element
  with no explicit CSS width/height can collapse.
- Image elements for content imagery the client may swap (logos, icons);
  CSS `url()` on a pseudo-element for decorative textures.

## Logo bands in a media carousel (§2)

A Bricks media carousel renders each slide as `div.image` with the file as
a lazy background-image, 300px tall by default, and NO per-item classes.

- Set the slide height in class-scoped custom CSS — the default is what
  makes tall marks look huge next to wordmarks.
- Per-logo scale: key it to the FILENAME, never `nth-child` (Swiper loop
  mode clones slides; any reorder shifts indexes). Bricks emits the URL in
  `data-style` before lazy-load and in `style` after, so match both:
  `.image[data-style*="/logo-x."], .image[style*="/logo-x."]{transform:scale(.74)}`.
  It survives reorders, additions and lazy-load. (Fallback: bake the scale
  into the PNG as transparent padding.)
- Adding a logo later: upload with alt ("Uploads that keep their
  filename and alt" above) → append it to `items.images` → add its
  filename to the tier selector list.

## Ornament scale by PPM run-length scan (§11 step 4)

Render the comp region with `pdftoppm -r 288 -x -y -W -H` to raw **PPM**
(drop `-png`), parse the P6 header in plain python, and run-length scan one
pixel row for ink runs. The run START positions give the pattern's repeat
pitch in points. The same scan on the web asset (via a canvas in the
browser pane — same-origin, so untainted) gives its pitch in pixels. Their
ratio IS the `background-size` scale factor. Verify with a second,
independent row: two rows agreed within 1%. Worked example:
`bottom-corner-pattern_750.png` (750×280, pitch 152.5px) vs comp pitch
125.25pt → scale 0.82.

## Recover type weight from ink width (§11 step 3)

When the design tool's inspector and the comp's pixels disagree on weight
and the export is a flat raster:

1. Confirm the comp font and the web font are the SAME family — a shared
   name root is not a shared typeface (a desktop cut vs a foundry's later
   webfont redesign is the common trap, and it is what makes a transcribed
   weight visible on the site for the first time).
2. Read the comp font's OS/2 and hmtx tables locally for the exact advance
   width in em of the measured string under each weight hypothesis.
3. Render the export at 1:1 (check the page box against the frame width —
   a 1440pt box for a 1440px frame means 1pt = 1 comp px), measure the
   line's ink bounding box, and divide by the em width per hypothesis.
   Only the true weight yields an implied font-size matching the declared
   size.
4. Validate on at least two lines whose built values are already trusted
   before trusting the disputed one, and prefer MULTI-LINE agreement: the
   wrong hypothesis produces a visible spread between lines of one block
   (20.96 / 20.95 correct vs 22.47 / 22.69 wrong), which is itself the
   discriminator.

## Multi-page rendered-state audit — same-origin iframe fan-out (§8)

Standard recipe for any multi-page rendered-state verification (typography
sweeps, colour audits, overflow probes, element-presence checks). N pages
in 2 browser calls instead of 2N:

1. From any page on the site, inject N hidden same-origin iframes
   (`position:fixed;left:-99999px;width:1440px;height:6000px`) pointing at
   each URL with a cache-busting query param.
2. In a second call, read `iframe.contentDocument` and
   `iframe.contentWindow.getComputedStyle()` for every iframe and
   aggregate in one JS pass, so the result arrives as one comparable table.

Caveats: same-origin only; the explicit 1440×6000 box is what makes media
queries resolve at desktop width and below-fold content lay out at all;
still cache-bust each `src`; check `readyState === 'complete'` plus a
sentinel selector before reading, and REPORT any frame that was not ready
rather than silently dropping it.

## Probe environment (§8 step 8)

Know these before calling something broken.

- Time- and viewport-driven behavior (enterView reveals, lazy-load,
  CSS animations) CANNOT be verified by waiting in the automation pane
  (frozen rendering clock — `getAnimations()[0].currentTime` stays 0,
  IntersectionObserver never delivers) nor in background Chrome tabs
  (`document.visibilityState === "hidden"`). Probe the clock before
  debugging "broken" observers. CSS keyframe animations CAN be asserted by
  SEEKING instead: set `currentTime` on each of `document.getAnimations()`
  and read computed style at chosen instants — deterministic, works in a
  hidden document, takes milliseconds (use it on the §10.5 safety-net
  keyframes). Observer-triggered reveals still need a foregrounded browser.
- Bricks lazy-hidden also suppresses `_cssCustom` background-images,
  not just `_background` ones — verify via emitted CSS + the bg-color
  fallback, never via a pane screenshot.
- Blank images in pane screenshots must be cross-checked with
  `img.complete` / `naturalWidth` before being treated as defects
  (pane paint-lag).
- Fresh pane tabs open at a NARROW default viewport, so mobile rules
  are active — `resize_window` to 1440 before trusting computed probes.
- Below-fold visual checks in the pane: measure with JS first so the
  proof never depends on pixels. For the pixels, keep scrollY 0 — real
  scrolling renders with a wrong-sign offset there — and hide the
  preceding siblings (`display:none`), shoot, restore: deterministic.
  Shifting content with `document.body.style.transform =
  'translateY(-Npx)'` has also come back as a white frame. To show a
  section in context, enlarge the emulated viewport (1440×1500) so it sits
  in the first screen.
- `getComputedStyle` during a transition's DELAY returns the START
  value. To assert a target state, inject `transition:none!important`
  first — otherwise a correct rule reads as "selector didn't match".
- **Pane clicks take SCREENSHOT-frame coordinates, not CSS pixels.**
  Convert: `shotXY = cssXY * (screenshotWidth / window.innerWidth)`
  (observed 800-wide shots against a 1280 viewport = ×0.625). A click
  landing on empty space returns the SAME success string as a real hit
  — the tool echoes the coordinate it received, never whether anything
  was struck — so always assert the resulting state (`location.hash`,
  `scrollY`, a DOM change) instead of trusting the click's return.
  Hit-testing stays accurate even when the pane screenshots blank
  below the fold, so a blank screenshot is not a reason to abandon a
  click test.
- **A hidden pane reports a ZERO viewport and every geometry probe becomes
  garbage** — card width 52px (real 617px), `backgroundImage: "none"` on an
  element whose id rule demonstrably carries a `url(...)`, derived "pattern
  height 4.7px". The numbers are internally consistent, so they read as a
  genuine specificity conflict. Return `innerWidth`/`innerHeight` alongside
  every geometry or computed-style payload and DISCARD any result where
  `innerWidth === 0`; one `computer:screenshot` call foregrounds the pane,
  then re-probe. Distinct from the frozen clock above: a frozen clock
  yields plausible wrong values, a hidden pane yields implausible ones.
- **A frozen clock reports every animation as broken.** Before trusting any
  negative result about an animation, scroll reveal, IntersectionObserver
  or lazy-load, read `document.visibilityState` AND run a control: inject a
  fresh trivial `@keyframes` opacity fade on a throwaway element, wait, and
  read its computed opacity. Control stuck at 0 = the clock is frozen and
  the observation is meaningless. A backgrounded real browser fails exactly
  like the pane (20/20 reveal elements read `opacity: 0` at 9.5s, all
  correct once foregrounded), so the fix is a FOREGROUNDED browser proven
  with a control, not "use a real browser".
- **`*{transition:none!important}` does not touch pseudo-elements.** The
  universal selector matches no pseudo-elements, so a `::after` knob keeps
  its own `transition: transform .2s` and the probe lands in the
  during-delay window above. Use
  `*,*::before,*::after{transition:none!important}`. Failure signature: one
  property ON the element reads final while a pseudo-element property reads
  start — indistinguishable from a broken selector.

## Pre-write render harness (§8 — spec-only or delegated section work)

When a section must be delivered as element JSON before anything is written
to the site, verify it against the closest real context, not the JSON's own
structure — a structural validator proves the tree is well formed, not that
it renders.

1. Curl the live target page (it brings Bricks frontend CSS, the theme
   style and the global-class CSS already in use).
2. Render the element JSON into equivalent Bricks markup (section/div/h2/p/a
   with the `brxe-*` ids and classes) and inject it into
   `<main id="brx-content">`.
3. Add the global-class CSS the page lacks (read-only `global_class:list`)
   plus the section's `_cssCustom`.
4. Probe in headless Chrome at both sides of each breakpoint and of the
   container max plus phone widths (e.g. 1440 / 1241 / 1240 / 991 / 768 /
   390 / 360): geometry, overflow, and copy as rendered at each width. Take
   element screenshots with a Playwright locator (`sips --cropOffset` did
   not crop from the top-left).

It caught a `<br>` that fused two words at the breakpoint that hides it
(§12) — invisible to every JSON check.

## Additive anchor element (§6)

- **Working additive-anchor recipe** (render-verified on a pilot build):
  `text-basic` with `text: "&nbsp;"` — non-empty content is MANDATORY —
  plus `_attributes`
  `[{id,name:"id",value:"<anchor>"},{id,name:"aria-hidden",value:"true"}]`,
  and ALL styling in `_cssCustom` keyed on the OVERRIDDEN id:
  `#<anchor>{position:absolute;top:0;left:0;width:0;height:0;
  overflow:hidden;pointer-events:none;scroll-margin-top:<offset>;}`
  Set NO structured style settings on it — those emit `#brxe-<id>` rules
  that are dead the instant `_attributes` replaces the DOM id, and they
  trip `verify:orphaned_css`. Check the intended parent is already
  `position:relative` before relying on `absolute` (§7 containing-block
  rule); absolute is what keeps the anchor out of flow — an in-flow anchor
  becomes an extra flex/grid item and consumes a `gap`. Set
  `scroll-margin-top` to sticky-header height + breathing room, or ~30px
  when the header is static.

## Global class on a wrapper so raw HTML inherits (§7)

Precondition: the raw element sits ALONE in its `text-basic` wrapper. Put
the global class on the WRAPPER (a real Bricks element), carry typography
in its `_typography` panel, and add a class `_cssCustom` rule of
`.<class> a{font-family:inherit;font-size:inherit;font-weight:inherit;
color:inherit}` so the inner anchor inherits whatever the panel is set to.
Panel edits then propagate to the anchor.

## Kses-safe toggle switch (§10)

`<input type="checkbox" id class>` + `<label for class>` inside a
text-basic survives `page:update_content` intact (curl-verified) via the
core plugin's kses allowlist, and pure CSS delivers the whole switch — no
JS for the visuals, only for persistence:

- `:checked + label` — track colour.
- `:checked + label::after` — `transform` for the knob.
- `:focus-visible + label` — focus ring; keep the input opacity-0 and
  clipped but still FOCUSABLE, in the same positioned wrapper as its label.
- `<span class="sr-only">` inside the label — the accessible name.

## Token pre-flight (§7)

Before committing to wire anything to a design token:

1. Fetch the GENERATED stylesheet and list which custom properties are
   ACTUALLY emitted and under what exact names. Global variables AND
   typography-scale variables written through the MCP are stored with
   their leading `--` and emit
   with a doubled prefix (`----lc-navy`, `:root{----lc-text-h1:56px}`)
   because the generator prepends its own, so `var(--lc-navy)` resolves
   to empty. The API cannot repair either — a variable name sent without
   dashes comes back normalized with them re-added (the fix is reachable
   only through the builder UI), and a scale prefix without `--` is
   rejected. A scale-created success response is not evidence; curl the
   emitted CSS for each path.
2. Grep for existing `var(` consumers to learn which layer is real. A site
   can carry three layers with different fates: a colour palette that emits
   usable properties, and a typography scale and global variables whose
   properties are usable or unreferenceable depending on the path that
   wrote them.
3. Round-trip one value per property TYPE through the builder field and
   read the emitted declaration — serialisation differs per field. `var()`
   works in the font-size and colour typography fields but NOT font-family,
   which the builder wraps in quotes (`font-family:"var(--x)"` is a family
   name, not a reference).

A token that resolves in `getComputedStyle` is not proof of correctness:
the broken and working spellings can both be present at once.

## Subgrid cross-card alignment (§7)

When sibling cards have variable-length headings or labels and their
following content must line up, do NOT put a `min-height` on the heading —
that hard-codes today's copy and un-aligns silently the moment a title
rewraps.

- Parent grid declares `grid-template-rows` with ONE ROW PER CONTENT SLOT.
- Each card gets `display:grid; grid-template-rows:subgrid; grid-row:span
  N`. Row heights then derive from the tallest card, no magic numbers —
  measured here: four bodies landed on the same offset automatically.
- **`row-gap` trap:** a subgrid INHERITS the parent's `row-gap` in the
  subgridded axis, so a responsive `row-gap` added to space ROWS OF CARDS
  also opens up INSIDE every card. Remedies: scope the subgrid to the
  breakpoints where the grid is a single row, or override the gap on the
  item.
- The Bricks CSS sanitizer preserves `@supports` nested inside `@media`
  verbatim, so a clean progressive-enhancement fallback is available in a
  builder-managed CSS field.

## ACF field-name collisions (§5)

Bricks keys `{acf_<name>}` by field NAME across every field group, so two
groups sharing a name (a post field and an options-page field both called
`tagline`) render one group's value in the other's context. List the
repeats from the exported field-group JSON before wiring tags:

```bash
python3 - <<'PY'
import json,collections,sys
names=collections.defaultdict(set)
def walk(fields,group):
    for f in fields:
        names[f['name']].add(group)
        walk(f.get('sub_fields',[]),group)
for g in json.load(open(sys.argv[1] if len(sys.argv)>1 else 'acf-export.json')):
    walk(g.get('fields',[]),g['title'])
print({n:sorted(v) for n,v in names.items() if len(v)>1})
PY
```

For each collision use `{cf_<name>}` (native meta, the post's own value) in
post context, or give the fields group-prefixed names at design time. A
repeater tag `{acf_<repeater>}` is not a tag outside its loop; `{cf_<repeater>}`
returns the row count. Sanity-check the script against a pair you know
collides before trusting a clean result.
