# Interactions + animations (Bricks-native)

Read before adding any interaction, scroll reveal, animation, or JS-free
menu — not needed for a page with none.

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
  Kill transitions with `*,*::before,*::after{transition:none!important}`,
  never `*` alone — see `reference/recipes.md` → "Probe environment".

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
Children of the overlay take `visibility:inherit`, never `visible`: a
sub-link set `visible` under the closed (`opacity:0`) overlay stays an
invisible tab stop (caught by an a11y review).

- Hover system: put states on classes (see §7 specificity note); include
  `:active` press states, `a:focus-visible` outlines, and a
  `@media (prefers-reduced-motion: reduce)` kill-switch in the same block.
- Active nav state: link nav items as INTERNAL (`{type:"internal",
  postId}`). Bricks text-link and dropdown elements then emit
  `aria-current="page"` (the dropdown toggle also gets class
  `aria-current`), so one `[aria-current=page]` rule in the header CSS
  covers every page — no `body.page-id-N #brxe-…` rules.
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
- The kses-safe toggle-SWITCH recipe (checkbox + label, no JS for the
  visuals) is in `reference/recipes.md`.
