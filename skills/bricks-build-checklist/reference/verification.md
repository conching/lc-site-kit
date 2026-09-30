# Verification recipe

Read after any structural edit and before declaring any change or PAGE
done. No write access yet (spec-only or delegated section JSON)? Run the
layout and copy probes below against the pre-write harness
(`reference/recipes.md`) before handoff.

1. Curl every touched page with `?nc=$RANDOM` (page caches lie; browsers
   show stale element CSS).
   A cache HIT is not evidence: assert the response headers too (`x-ac:
   … HIT`, `server-timing: cache;desc=HIT`). A passing check against a
   cached body manufactures false confidence in BOTH directions, hiding
   real breakage as readily as real success. Count occurrences with
   `grep -o … | wc -l`, NEVER `grep -c` — minified builder markup puts
   many elements on one line, so a 6-card page counted 2.
   The mirror trap on PRODUCTION: a passing cache-busted fetch proves the
   origin, not the visitor's page. Connector element writes update post
   meta without firing the hooks the page cache listens to, so after any
   write to a production page fetch the PLAIN URL (no query string) and
   assert the change is there with the cache header going MISS → HIT. If
   the plain copy is stale, fire a no-op `page update_meta` (same title) to
   trigger the `save_post` purge, wait ~15 s, re-fetch. Note per host which
   writes purge (one managed host: post save yes, element/meta writes no). Never
   declare a production edit done on a cache-busted fetch alone.
   STAGING has the same trap (a server-level Varnish plus a page-cache
   plugin; template writes through the MCP purge neither). After any write,
   request the page TWICE — with and without the cache-buster — and compare
   `x-cache` / `age`: a plain URL that is a HIT older than the write is what
   the client and reviewers actually load (seen: nav present on `?nc=`,
   absent on `/`, and a headless capture of an empty "Nothing found"
   page). Purge both layers, or disable Varnish on staging for the duration
   of a build. (Code fix, MCP plugin: purge affected URLs after
   page/template/element writes.)
2. Section-order assert (rule 1) per page, per render mode.
3. Overflow scan at desktop + narrow simulation (exclude
   `#claude-phantom-*`, `#wpadminbar`, and `position:fixed` elements):
   `getBoundingClientRect().right > clientWidth` count must be 0 — and
   `document.documentElement.scrollWidth === clientWidth` (intentional
   full-bleed elements may report rects past the edge while clipped).
   Then a CLIP scan: for every element walk to its nearest clipping
   ancestor and assert its rect does not exceed that ancestor's — count
   must be 0 at every breakpoint. A rule that changes only PAINT is
   invisible to the overflow scan and the order assert (§7
   `overflow:hidden`), and this is the only probe that catches it.
4. Computed-style probes for backgrounds (rule 3) — not screenshots;
   below-fold sections and `_cssCustom` bg-images render blank in
   automation screenshots even when correct.
5. Anchor-id integrity: for every section whose rendered id is NOT
   `brxe-`-prefixed (it carries an `_attributes` anchor id, cf. rule 6),
   assert its background/padding still computes as intended — OR run
   `verify:orphaned_css`. Fix = dual selector or migrate the id to an
   additive anchor element (§6 recipe).
   **`verify:page rendered` CANNOT see these elements.** It enumerates
   only `id="brxe-<id>"`, so anything carrying an `_attributes` id
   override is structurally invisible to it — the tool returns http 200
   and a complete-looking ordered list that silently omits exactly the
   elements you just added. Absence there is not evidence of absence.
   Prove anchors with a literal grep of the served page
   (`grep -c 'id="<anchor>"'`), and expect the count to be exactly 1 —
   0 means skipped (§6), 2+ means the old element was never removed.
   Same blind spot as §1's order-grep trap, one layer up in the tooling.
6. If a conditional mode exists (alert vs normal), fire-drill BOTH
   directions and re-run the asserts in each.
7. Screenshot only for above-fold composition; use `zoom` region captures
   for detail claims.
8. **Environment limits** — know these before calling something broken:
   `reference/recipes.md` → "Probe environment" (frozen clocks, hidden
   panes, lazy-hidden backgrounds, transition delays, pane-click
   coordinates). Read it the moment a probe returns a surprising negative.
   Verify instead: assert emitted config/CSS statically, design fallbacks
   that fail visible (§10.5), and get a human glance for final motion QA.
9. **Sweep discipline — a sweep that cannot fail is not a sweep.**
   - Shell loops run under zsh, which does NOT word-split unquoted
     variables: iterate with `while IFS= read -r x; do … done <<< "$list"`,
     never `for x in $list`, and match literals with `grep -qF` so a stray
     newline can't turn one pattern into an alternation. Both bugs together
     made an 11-page anchor sweep report "missing: none" — including a page
     with a known dead anchor — with perfectly plausible output.
   - Sanity-check every sweep against one input whose answer you already
     know INDEPENDENTLY. Automated checks fail toward "clean": empty list,
     unsplit variable, unmatched pattern all produce zero findings. When a
     new check disagrees with an earlier verified result, the NEW check is
     the suspect.
   - "Find every instance of <visual property>" needs TWO passes: parse
     stored CSS to locate the editable SOURCE of each rule, then a
     `getComputedStyle` sweep over rendered pages to establish what
     actually RENDERS. Pass 1 says where to edit, pass 2 says what to edit;
     never edit off pass 1 alone. Three failure modes: a class rule
     overriding an element-id rule on a nested child (2 false positives in
     139 bold declarations), theme/plugin CSS files outside the scanned
     surface (7 missed form labels), and a higher-specificity rule pulling
     a value back out of range (18 `<strong>` tags at 500).
   - Multi-page sweeps: same-origin iframe fan-out audits N pages in 2
     browser calls instead of 2N — `reference/recipes.md`.
   - When a user reports a symptom that CONTRADICTS data already gathered
     this session, RE-MEASURE before explaining it away. Observations decay
     on a live site: four elements audited as correct 20 minutes earlier
     had lost their utility class to a concurrent builder editor. Treat
     "the client is looking at the site right now" as an active-editor
     signal — spot-check a couple of untouched elements before a batch of
     writes, and have them reload the builder before saving.
10. **Large writes: read back the FRONT END with a script**, not by
    pulling the stored tree into context. After a 128-element (66 KB)
    `update_content`, a cache-busted curl plus a short script checked
    against the local source JSON: every element's DOM id exists, every
    non-comment line of every `_cssCustom` appears verbatim in the page
    CSS, every base64 data URI is intact, every text run, alt text,
    `_attributes` name="value" pair and external href is present, and eager
    images are not lazy-wrapped. Report only the mismatch count and the
    mismatches; zero tree bytes in context, and it checks what the visitor
    gets. Known false positive: splitting text on `<br>` joins words unless
    the parts are split first. Keep the stored-tree diff for small edits and
    for settings that never surface in HTML (element conditions,
    interactions).
11. **Lazy-load, proven per width and with JS off.**
    - Which images actually DOWNLOADED, per width (e.g. 390 / 768 / 1440:
      a pilot interior page fetched 1 / 2 / 3), against the eager/lazy decision (§2):
      eager images carry a real `src`, tier-hidden images are never
      fetched (Bricks JS lazy skips `display:none`).
    - Once per recipe, load the page with JavaScript disabled (Playwright
      `javaScriptEnabled:false`): `bricks-lazy-hidden` stays on the
      element and its own `background-image` computes `none`, while
      `getComputedStyle(el,'::before').backgroundImage` still returns the
      url — direct proof the §3 pseudo-element recipe survives.
12. **Pixel probes where the claim is visual.**
    - Section seams: sample the per-channel MIN (not the average) of the
      boundary pixel row in a full-page screenshot at each breakpoint. An
      average of 255 hid a min of 254 where pattern glyphs bled through a
      gradient whose end stop lands on the final half-pixel; end fades with
      a few px of solid hold at the target colour (6px made it 255 at
      every width).
    - Text over a photo or scrim: record each text line's client rects,
      set the text `color:transparent`, screenshot, and compute WCAG
      contrast of the text colour against every pixel in each line box.
      Run it at every tier boundary plus 1280/1366; require worst pixel
      ≥ 3:1 for large text and ≥ 4.5:1 for body, and report p95 beside it.
      A percentage scrim holds only at the comp width (a values-card band: 3.22:1
      at 1440, 2.66:1 at 1241–1439, because narrower cards wrap taller and
      lift the titles into the lighter part of the gradient). Where text
      height varies with width, anchor the scrim to the text block (a
      pseudo-element on the text wrapper extending N px above it).
13. **Accessibility minimum.** Focus ring visible at ≥ 3:1 on EVERY band
    (a single brand-colour outline failed on light bands; a two-tone ring,
    outline plus contrasting box-shadow, passes on light and dark); no
    child of a hidden overlay set `visibility:visible` (invisible tab
    stops — `reference/interactions.md`); nav is a landmark with `ul`/`li`
    (a Bricks dropdown renders an `<li>`, so its parent must be a `ul`);
    and read the page's heading outline.
14. Run the §11 fidelity pass before declaring a PAGE done.
15. Run the §12 responsive probes before declaring a PAGE done.
