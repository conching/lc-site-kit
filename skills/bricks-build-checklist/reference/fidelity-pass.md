# Design fidelity pass (comp-diff)

Read before declaring any PAGE done, and again before every design-fix
round.

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
   files drift after approval (observed on a pilot build, same-day).
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
   - [ ] **Decorative layers ONLY ONCE:** the check above is one-way — it
         catches a MISSING decoration, not a duplicated one. For each
         decorative layer, also assert the page renders exactly ONE
         implementation. Before adding a decoration, grep the page for the
         other known hooks (utility classes, `::before`/`::after` on
         ancestors, background-images on wrappers); the cheap probe is
         `getComputedStyle(el,'::after').content` across siblings. Two of a
         pilot build's cards kept a legacy `.lc-pattern-corner` class alongside the newer
         per-column ornament — two artworks, two scales, two anchor boxes,
         composited. The other three had lost the class in a rebuild, so
         the defect read as an INCONSISTENCY between siblings, not as an
         error on any one card.
   - [ ] **Typography rhythm:** display line-height (comps run ~1.1, Bricks
         default 1.4 — measure line spacing off the band), intentional
         line breaks, heading widths.
   - [ ] **Assets as displayed:** every image compared against the comp's
         crop/tint — raw-source montages and baked-bounds exports jump out
         here (§2 displayed-node rule).
   - [ ] **Asset ink ratios across the whole SET:** compare every sibling
         asset's `naturalWidth/naturalHeight` against its comp ink ratio in
         one pass — the outliers name themselves. Several of a pilot
         build's badge PNGs had been exported with the ring cut off (ink
         ratios ~1.1–1.4 vs comp ~0.9–1.0) while the healthy ones matched
         within 0.3%.
3. **Calibrate before trusting any comp-derived measurement.** Solve an
   element already BUILT AND APPROVED and confirm your method returns its
   known value. Compare ink-to-ink
   (`actualBoundingBoxLeft/Right`), never ink-to-advance; measure cap
   height off a flat-topped capital only. Where the comp font and the
   shipped font differ, the substitution is a known fidelity CEILING —
   record it and put the residual on the punch-list instead of chasing it.
   Never transcribe a numeric font-weight ACROSS families — resolve it to
   the named cut (Regular / Medium / Bold) and pick the web family's
   equivalent. A design tool's inspector reports the weight a layer
   REQUESTED, not the one it drew, so it lies exactly when the cut is
   missing; when the inspector and the comp's pixels disagree, solve the
   weight from measured ink width against the font's own metrics —
   `reference/recipes.md` → "Recover type weight from ink width".
4. **A spec measured on a sample of comps is a HYPOTHESIS for the rest.**
   Before batch-applying a type rule to page N, verify N's declared value
   (`get_design_context`) or its PDF. Distinguish component VARIANTS
   (left-aligned section H2 vs centered display header) before unifying
   sizes — "one size everywhere" sweeps have been wrong twice.
   For a repeating or textured element, measure the REPEAT PITCH, not the
   visible extent — the extent is clipped by its container and varies per
   card, the pitch is invariant. Eyeballing a decorative pattern band off a crop was
   ~35% off; the pitch scan was within 1% across two independent rows.
   Recipe: `reference/recipes.md` → "Ornament scale by PPM run-length scan".
   For repeated rows or cards, compare EACH instance's text positions to
   the comp separately — never hand row 2 row 1's gap set when the design
   shows per-instance drift (repeated rows on a later build: row 2 missed by 4.3 / 3.7 px).
   Take positions from glyph cap-tops (`pdftotext -bbox` on the comp PDF),
   not Figma text-box tops, which include fixed-height padding (a 38-tall
   subtitle box understated its text by ~3 px). After ANY CSS override,
   re-probe the computed box: an override placed before a same-specificity
   shorthand (`margin:31px 0 0`) is dead, and only the re-probe shows it.
5. **Audit which font weights the kit actually serves.** A declared weight
   the kit doesn't ship renders silently ONE WEIGHT DOWN, site-wide, from
   day one. Fetch the kit CSS (e.g. `use.typekit.net/<id>.css`), parse
   `@font-face`, and confirm every weight in use is present. Beware
   near-miss family names — a base family may ship only display weights
   while the usable upright range lives under a `-pro` sibling. Then prove
   the face actually LOADS on the page:
   `[...document.fonts].map(f=>f.family+' '+f.weight+' '+f.status)`, the
   font CSS's resource entry
   (status 400 / `transferSize` 0 = dead), and a canvas `measureText`
   width against `sans-serif`. A declared family that never loads (a
   retired Google family name) falls back to system sans for every
   visitor — a finding in its own right, before any type or spacing fix.
6. Anything intentionally divergent goes on the client punch-list — a
   deviation is a decision, never a silent default.
   A punch-list entry must carry the REJECTED alternative and who rejected
   it, not just the divergence — otherwise a later fidelity pass
   "corrects" a deliberate client choice back to the comp. Record all
   three: the comp measurement, the value the client first asked for, and
   the value they settled on, with an explicit "do not correct this to the
   comp" marker. (a pilot build's process cards: comp 57.6/42.4, client asked 2/3,
   client settled on 60/40.)
7. **Migrating from a static prototype: audit reused JS/CSS for structure
   assumptions, and check generated UI separately.** Before building, grep
   the prototype's scripts and stylesheets for child combinators (`>`) and
   `:first-child` / `:last-child` / `:nth-child` on content containers, and
   list every selector whose parent may gain a Bricks wrapper (the
   post-content element, loops, template wrappers). Widen the selector or
   build the markup flat. A text/heading/link parity diff proves the data
   arrived, not that behaviour built on its structure still runs: add
   "JS-generated UI (TOCs, pill navs, counters) exists on staging" to the
   parity checklist and compare section heights per page. (A script that
   built an in-page nav from `.body .container > h2` found 0 headings
   inside the post-content wrapper on 4 of 12 pages, while every content
   diff passed; `h2:first-child` margin resets kept matching inside the
   wrapper too.)
8. Assets needed during the pass come from the SAME PDF: `pdfimages -png`
   emits RGB + SMask pairs (recompose for alpha) at placed resolution.
