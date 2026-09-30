# Responsive pass

Read before declaring any PAGE done.

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
- A soft break that becomes `<br>` and is hidden at some breakpoint needs
  a SPACE before it — `from <br>the`, never `from<br>the`, which
  renders "fromthe" wherever the `<br>` is `display:none`. Check every
  Figma soft break (U+2028) when converting copy.
- Sweep the 768px TABLET range explicitly. Mobile-only fixes written at
  ≤767 leave a gap at 768–991 that no phone check catches.
- Re-measure every responsive fix AT the width it targets. A `clamp()`
  floor or cap applies only where the preferred value reaches it: a
  reviewer's "lower the clamp floor" did nothing at 320 because the vw term
  was still above the floor there, and only the post-fix measurement
  caught it.
- Wide content (matrices, tables) gets an `overflow-x` scroller plus a
  sticky first column and a visible swipe affordance.
- Probe `scrollWidth === clientWidth` + the per-element right-edge scan
  (position:fixed excluded) at **375 / 768 / 1440** per page before "done".
- **Widths come from the layout, not from a device list.** Probe each
  breakpoint BOUNDARY and both sides of it (991/990, 767/766, 478/477),
  PLUS at least one width in the band between the largest breakpoint and
  the container max-width. 992–1300 is where a max-width container is no
  longer at max but desktop rules still apply, and it is the width least
  likely to appear in any device preset: a CTA band with two fixed-width
  flex children (824px + 290px, needing ~1150px) overflowed by 61px at
  1024 after a "probe-clean at 375 / 768 / 1440" sign-off.
- Pre-sign-off, run the orphaned-CSS scan on EVERY page touched.
  Responsive overrides are id selectors written against a layout that may
  later be rebuilt; a dead selector is invisible at desktop and shows only
  as "the breakpoint does nothing" (a card grid that never stacked, three
  dead selectors, 3 → 0 the moment the ids were repointed). When a section
  is rebuilt with fresh ids its responsive carrier does NOT follow — it is
  a separate surface and must be re-pointed (§1).
