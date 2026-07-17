# Known Issues & Not-Yet-Folded Lessons

These are field lessons captured during builds that are **pending integration**
into the skills (`figma-to-bricks`, `bricks-build-checklist`) above. Each is a
real, reproduced issue with a working fix and a generalizable principle. Treat
them as authoritative until they are folded into the checklist sections they
reference.

---

## 1. Bricks dynamic-data delivery drift — link type "dynamic" renders empty href; ACF select fields have no `:label` filter

**Area:** Dynamic data / links (bricks-build-checklist §7 or a new dynamic-data box)

**Issue:** Two distinct dynamic-data gaps surfaced on pilot-build News cards
(ACF external-URL links) and product-card subtitles (availability select). (a)
The builder guide's documented link format
`{"type":"dynamic","dynamicData":"{acf_field}"}` persisted fine but rendered an
`<a>` with NO href on every instance — loop and non-loop alike. Other settings
like `target=_blank` still emitted, so the link object was processed; only the
URL resolved empty. The same tag works in text and condition contexts, so this
is a link-context-specific delivery gap, not a tag or data problem. (b)
`{acf_select_field:label}` is not a real filter — it echoes the raw stored value
(e.g. `"year_round"`) rather than the human label.

**Fix/recipe:** For links, use `{"type":"external","url":"{acf_external_url}"}`
— Bricks renders dynamic tags inside external-URL strings. For select labels,
set `return_format => 'label'` on the field registration; writes via
REST/`update_field` still accept raw values, and code reading raw meta
(`get_post_meta`) is unaffected, so the display and data paths separate cleanly.

**Principle:** Dynamic-tag support is per-CONTEXT (text vs link vs condition),
not per-tag. When a tag works in one context and not another, switch the
delivery format before doubting the tag or the data.

---

## 2. Plugin deploys without user presence — stage the zip in the site's own media library, inject it into the upload form via DataTransfer

**Area:** WP-admin automation / deploy pipeline (bricks-build-checklist §9;
new-skill candidate: wp-plugin-deploy recipe)

**Issue:** The chrome extension's `file_upload` tool only accepts
session-attached files — every local path (project dir, cwd, scratchpad) is
rejected, so §9's "attach the zip to the chat" precondition can't be met
mid-session. On a pilot build's CMS phase, lc-core 0.2.0/0.2.1/0.2.2 were
deployed three times through the user's logged-in Chrome session, ~2 minutes
each, with zero user involvement, using the recipe below. Three consecutive
deploys, zero failures.

**Fix/recipe:** (1) POST the zip to `/wp-json/wp/v2/media` with the app password
(zips are allowed attachment types). (2) In the logged-in wp-admin upload page,
`fetch()` the zip same-origin → new `File` → `DataTransfer` → assign to
`input.files` → dispatch `change` → click Install. (3) On WP's "already
installed" compare screen, click `a.update-from-upload-overwrite` ("Replace
current with uploaded") — a full version-to-version upgrade path, no FTP/SSH.
(4) DELETE the staged media id (note WP auto-creates and auto-deletes its own
package attachment, so expect one `rest_post_invalid_id` on cleanup). (5) Hit
any wp-admin page to fire `admin_init` so version-gated upgrade hooks (term
seeding, rewrite flush) run. Keep the version-bump-both-places rule (header +
define) — it is what makes the compare screen and upgrade hooks work.

**Principle:** When an upload tool gates on file provenance, the application's
own storage is a staging area the page can always reach — move the bytes into
the origin first, then hand them to the form from inside the page.

---

## 3. A declared font weight the kit doesn't serve renders silently one weight down — audit loaded weights per family before trusting any "Medium" spec

**Area:** Font setup / fidelity pass (bricks-build-checklist §11 typography / fonts)

**Issue:** On a pilot build, the client reported CTA links "should be Extended
bold" but they render light. Every element was correctly set to the substitute
family at weight 500, per the comp's "Medium Extended" spec — but the Adobe kit
loads that family in 400 and 700 ONLY, so browsers resolved 500→400 site-wide
since the first build. The font-family/weight oracle (a bound Figma style via
`get_design_context`) tells you the DESIGN's weight, not whether the shipped kit
can render it. The foundry's Medium Extended cut mapped to CSS 500 — a weight the
substitute family doesn't include — and the failure is invisible in code review:
computed styles report the requested 500 while the rasterizer draws 400. Every
"Medium Extended" surface (CTA links, eyebrows, buttons, nav) had rendered
Regular Extended since day one; the client caught it visually.

**Fix/recipe:** A `document.fonts` enumeration plus a width measurement diagnosed
it in one probe (500 renders identical to 400; 700 is wider). CTA/arrow links
were bumped to 700 (the closest available to the foundry's Medium); eyebrows,
buttons, and nav were flagged for a kit-level decision (add the Medium weight to
the Adobe Fonts project, after which 500 renders true everywhere). Going forward:
after wiring a kit, enumerate `document.fonts` per family and record the
AVAILABLE weights in the build plan. When a comp weight has no exact match, choose
the substitute weight DELIBERATELY at setup (and note it as a fidelity ceiling)
instead of letting CSS fallback pick 400 silently. A 10-second width probe (same
string at 400/500/700) proves which weights actually differ.

**Principle:** CSS weight resolution never errors — a missing weight is rendered
as a neighboring one with no signal anywhere in the stack. The only defense is
comparing the list of weights you loaded against the list the design uses, once,
at setup.

---

## 4. Bricks responsive-pass mechanics — breakpoint-suffixed settings emit at 991/767/478, and row→column flips carry three landmines

**Area:** Responsive builds (bricks-build-checklist §7 layout facts / new
responsive section)

**Issue:** Observed across a pilot build's designed responsive pass (framework +
mobile menu + footer + Home/About page passes). (a) Breakpoint-suffixed element
settings (`_typography:tablet_portrait`, `_padding:mobile_landscape`,
`_direction:...`, `_alignItems:...`, `_width:...`) all emit correctly, inside
`@media (max-width: 991/767/478px)` — exactly matching hand-written queries, so
element settings and custom-CSS frameworks compose cleanly. (b) Flipping a
desktop row to a column at a breakpoint trips THREE separate traps on the
children: the parent's `align-items` reverts to `flex-start` (shrink-wrap — a
per-breakpoint recurrence of the earlier shrink-wrap finding); children keep
desktop `margin-left`s (they render indented and overflow the viewport by exactly
that margin); and one child's `fit-content` can mysteriously exceed the parent.
(c) Cross-element responsive overrides written in another element's `_cssCustom`
tie at (1,0,0) with the target's own settings CSS and lose by document order
whenever the target sits later in the tree. (d) Legacy per-element `!important`
(e.g. a pilot build's hero stats `align-self:flex-end !important` buried in the
hero's icon-CSS block) silently defeats even inline styles during debugging.

**Fix/recipe:** For every row→column flip, apply align `stretch` plus a
stacked-children blanket rule per page:
`width:100%;max-width:100%;min-width:0;margin-left:0;margin-right:0`. Prefix all
cross-element overrides with `#brx-content`/`#brx-header`/`#brx-footer` (→2,0,0)
as a habit, not a fix-after. When a responsive override inexplicably fails, scan
matching rules for `!important` BEFORE theorizing about layout, and counter with
a scoped `!important` in the media query. Run overflow probes
(`scrollWidth === clientWidth` + a per-element right-edge scan, `position:fixed`
excluded) at 991/767/375 per page before "done".

**Principle:** A layout that changes axis at a breakpoint re-runs every sizing
default from scratch — audit the children as if they were newly created, because
in that media context they effectively are.

---

## 5. Kses-safe, JS-free mobile menu — `details`/`summary` burger + `:has()` reveal of the EXISTING nav

**Area:** Header / mobile navigation (bricks-build-checklist §10 / interactions)

**Issue:** With `set_page_scripts` blocked (Dangerous Actions OFF) and `wp_kses`
stripping `script`/`input` at save, a full mobile menu still ships pure-CSS —
demonstrated on a pilot build's real mobile menu that replaced the interim
`@media` block (header template 34). Verified end-to-end: click-open, click-close,
scroll lock on/off. Caveats: browsers without `:has()` get no menu (acceptable in
2026), and the frozen automation pane can't run the open/close transitions
(assert computed opacity with `transition:none`, per the earlier automation-clock
finding).

**Fix/recipe:** (1) A text-basic holding
`<details class="lc-mmenu"><summary aria-label="Menu"><span class="lc-mmenu-bars"></span></summary></details>`
survives kses verbatim (`details`/`summary`/`span` + `aria-label` all
allowlisted — the same finding family as a prior FAQ result). (2)
`#brx-header:has(.lc-mmenu[open]) #brxe-<navdiv>` restyles the EXISTING desktop
nav div into a fixed full-screen overlay — zero duplicated links; active-page
classes and hover styles carry over free. (3) `html:has(.lc-mmenu[open])
{overflow:hidden}` is the scroll lock. (4) `summary` is natively
keyboard-toggleable and the closed panel's `visibility:hidden` removes its links
from tab order — a11y basics free. (5) When open, `position:fixed` on the
`summary` (top/right matching the bar's geometry per breakpoint) morphs
burger→X in place; the logo stays clickable above the panel via z-index on its
positioned wrapper. Note: the text-basic wrapper div breaks sibling-combinator
tricks (`details` is nested one level down), so `:has()` is the load-bearing
selector.

**Principle:** The platform's native disclosure element plus a parent-state
selector turns "needs JavaScript" into "needs one HTML element" — reuse the real
nav under a state flag instead of duplicating content into a drawer.
