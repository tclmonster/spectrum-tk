# spectrum-tk Next Steps

> Status: living document. Curates the work queue so that any agent — or returning human — can pick up where the project left off without spelunking through `git log`.

For the layered design these steps slot into, read [architecture.md](architecture.md). For the smoke-test pattern referenced below, read [smoke_testing.md](smoke_testing.md). For project orientation, the root `CLAUDE.md`.

This file is ordered roughly by **what to tackle next**, but each section is self-contained.

---

## Open issues (carry-over)

### `<<ThemeChanged>>` binding does not fire on `[winfo class .]`

`spectrum.tcl` registers binding callbacks on the appname class (e.g. `Tk`, or whatever the script's appname turns out to be):

```tcl
bind $appname <<ThemeChanged>> +[list [self] refreshStyles]
```

In Tcl/Tk 9.x these bindings never fire — `<<ThemeChanged>>` is dispatched to ttk widgets, then propagates through their bindtags (`.f` → `TFrame` → `.` → `all`); the appname class is not in those tags. As a workaround `theme use` invokes the refresh methods directly (see `spectrum.tcl::Theme::use`).

**To fix:** investigate where `<<ThemeChanged>>` actually originates in Tcl/Tk 9 (likely on `.` or `all`) and update the binding target. Then confirm dark-mode toggling and external `ttk::style theme use` calls still work, and remove the direct invocation if redundant. Smoke recipe in `smoke_testing.md`.

---

## Phase 1 — Theme foundation: remaining work

ttk coverage is **done**. Classic widget option database is **done**. Two pieces left:

### Spectrum 2 token audit per ttk class

Initial styling for every ttk class is in place, but each class needs to be cross-checked against `spectrum-css/components/<name>/themes/spectrum-two.css` (with the `index.css` base for non-overridden values) to confirm token choices match Spectrum 2. The s2-docs MCP is the preferred entry point for behavioural specs (cursor, focus, transition); CSS files are the spec for color and density. The `s2-docs/components/` markdown is a fallback when the MCP returns nothing.

**Audited and aligned:**

- TButton (default / Primary / Accent ramps) — vs `button/`
- TEntry, TSpinbox, TCombobox (field bg, borders, selection fg) — vs `textfield/`, `picker/`
- TSeparator, TPanedwindow Sash — vs `divider/`
- TScrollbar thumb + arrow — vs `scrollbar/`
- Treeview (body, heading, border, row height, heading bold font) — vs `table/`, `treeview/`

**Not yet audited:**

- TLabel, TFrame, TLabelframe
- TMenubutton — vs `picker/` or `actionbutton/`
- TNotebook — vs `tabs/`
- TProgressbar — vs `progressbar/`
- TScale — vs `slider/` (only kitchen-sink visibility fix has landed; not a full audit)
- TCheckbutton, TRadiobutton — SVG indicators are in place; label / spacing / disabled-content colors not formally cross-checked vs `checkbox/`, `radio/`
- TSizegrip — has no Spectrum equivalent; verify it sits unobtrusively on `background-base-color`
- TScrollbar track + chevron stroke — partially done (thumb + arrow ramp); verify track fill and arrow stroke against `scrollbar/`

Pattern: for each class, read the matching `spectrum-css/components/<name>/themes/spectrum-two.css` (and `index.css` for the base), tabulate current vs Spectrum 2, propose the diff, smoke + visually verify in `kitchen-sink.tcl`, then commit with a focused message naming the source CSS files. See the recent `Align Treeview with Spectrum 2 ...` commit as a template.

### RGBA token handling

`gen-spectrum-vars.tcl` currently drops every token whose value is `rgba(...)`. For Phase 3 components that need overlays, focus rings, scrim, or hover tints, a path forward is needed. See architecture.md §Transparency. Implementation is deferred until the first concrete need arises (likely focus ring on Button or Toast/Popover).

---

## Phase 2 — OO infrastructure

Not started. Three artifacts need to land here:

### `components/_component.tcl` — `::spectrum::Component`

`oo::abstract` base. Wraps a Tk widget path and gives it an OO surface: rename the widget command into the object's namespace, `interp alias ::$path` to `[self]`, bind `<Destroy>` for cleanup, `unknown` method delegates to the underlying Tk command. Pattern is in the project memory and discussed in architecture.md §Phase 2.

### `gen-spectrum-components.tcl` → `spectrum-components.tcl`

Mirror of `gen-spectrum-vars.tcl`. Reads two inputs from the `spectrum-design-data` submodule:

1. `packages/tokens/src/*.json` — groups tokens by `component` field (92 components — see architecture.md) for the styling property bag.
2. `packages/component-schemas/schemas/components/<name>.json` — for the prop surface (variants, sizes, boolean states, defaults).

For each component, emits an `oo::abstract create ::spectrum::token::ComponentName { ... }` class using `oo::configurable` properties. Token-derived properties map to camelCase (e.g. `-backgroundColorDefault`); schema-derived properties keep the schema's exact key (`-variant`, `-size`, `-isDisabled`). The generated file is checked in. Run with `tclkitsh`.

When implementing concrete components, also read `spectrum-design-data/docs/s2-docs/components/<category>/<name>.md` for behaviour specs (keyboard focus, tooltip behaviour, cursor style, transition timing) and cross-check the visual mapping against `spectrum-css/components/<name>/`.

### Lowercase command-style aliases

After all concrete component files are sourced, sweep `info class subclasses ::spectrum::Component` and emit a lowercase command for each (`spectrum::Button` → `spectrum::button`). The lowercase form composes idiomatically with `pack`/`grid`/`place`. Single sweep at package init time.

---

## `gen-spectrum-icons.tcl` → `spectrum-icons.tcl`

Not started. Third generator in the family (alongside `gen-spectrum-vars.tcl` and `gen-spectrum-components.tcl`).

**Inputs:**
- `spectrum-css-workflow-icons/icons/assets/svg/S2_Icon_<Name>_20_N.svg` — 396 SVGs at viewBox 20×20 with `fill="var(--iconPrimary, #222)"`. The generator strips the `var(...)` and leaves the fill as a substitution slot.
- `spectrum-css-workflow-icons/icons/assets/components/icon<Name>.d.ts` — useful as the *shape* model for the wrapper signature; we don't consume the JS.

**Output:** `spectrum-icons.tcl`, a checked-in file with one proc per icon, mirrored to PascalCase (`S2_Icon_AlertTriangle_20_N.svg` → `::spectrum::icon::AlertTriangle`).

```tcl
spectrum::icon::AlertTriangle ?-size $px? ?-color $color?
;# returns a Tk photo image name suitable for -image on any widget that
;# accepts photos (Button -image, Label -image, etc.)
```

`-size` defaults to 20 (the icon's natural viewBox); `-color` defaults to a theme-token equivalent of `currentColor` (e.g. `$::spectrum::var(neutral-content-color-default)`). The generator substitutes both into the SVG body and rasterizes via `::spectrum::priv::svg_image`, which already caches by content + DPI.

A second sweep emits a manifest map (`::spectrum::icon::names` → list of icon names) for runtime introspection. No per-icon `oo::class` — these are pure factory procs because icons have no instance state once produced.

When the schema-driven Phase-3 generator hits `properties.icon` (as in `button.json`), the concrete component wires the `-icon` configurable to call into this namespace, so usage is `spectrum::button .b -icon AlertTriangle`.

---

## Phase 3 — Concrete components

Not started. Recommended start order (proven mechanism, then breadth):

1. **Button** — direct ttk wrapper. Establishes the `Component` pattern + variant prop mapping (`-variant accent|primary|secondary|negative`).
2. **Switch** — image-element-driven; reuses the SVG photo factory pattern from Checkbutton.
3. **TextField** — TEntry wrapper plus floating label, validation/help text composition.
4. **Checkbox** — already has the indicator element; the concrete class wires up `-isIndeterminate` and the label.
5. **Tooltip** — first transient `toplevel` component; sets the pattern for Popover, Toast, ContextualHelp.

Then iterate by Spectrum's catalog. The canonical component list is `spectrum-design-data/packages/component-schemas/schemas/components/*.json` (80 components); the matching design guidelines are under `spectrum-design-data/docs/s2-docs/components/{actions,containers,feedback,inputs,navigation,status}/<name>.md` and the CSS reference implementation is under `spectrum-css/components/<name>/`. Tier breakdown (direct ttk / composite / canvas-drawn) is in architecture.md §Phase 3.

---

## Test suite scaffolding

`docs/test_strategy.md` describes the intended layout (`test/all.tcl`, `test/components/*.test`, etc.) but no test files exist yet. Once Phase 3 begins:

1. Create `test/all.tcl` that sources every `*.test`.
2. Add `test/helpers.tcl` with shared setup (a fresh root window, `xvfb-run` shim for headless CI).
3. First test files: `test/tokens.test`, `test/theme.test`, `test/ttk_styles.test` (asserting the per-class lookups we already verified by smoke).
4. Each new concrete component lands with its `test/components/Foo.test`.

Tests use `tcltest` + `event generate`. No mocking, no screenshot diffing. Conventions and examples in `test_strategy.md`.

---

## Polish opportunities (lower priority)

- **Focus ring rendering.** ttk's default focus ring is a 1px dotted line; Spectrum uses a 2px solid blue ring at ~2px offset. Implementing this likely needs an SVG image element wrapping each focusable widget.
- **Animation plumbing.** `::spectrum::priv::animate` for ~130ms hover/press transitions and indeterminate spinners. Outlined in architecture.md §Animation; not yet built.
- **More TButton variants.** Currently default + Primary + Accent. Spectrum 2 also defines Secondary, Negative, Outline, and Quiet variants.
- **Treeview row alternation.** Spectrum tables sometimes alternate row backgrounds; ttk supports this via tag binding (`tags add evens` etc.). Could be a configurable theme option.
- **Kitchen-sink improvements.** Add disabled-state samples for every widget (currently only some have them); add an "image elements" tab that displays each generated photo at native size for visual debugging.

---

## When in doubt

- **Where does this token come from?** → `spectrum-design-data/packages/tokens/src/*.json`
- **What is this component's prop surface?** → `spectrum-design-data/packages/component-schemas/schemas/components/<name>.json` (or the matching `docs/markdown/components/<name>.md`)
- **What does this component look like / behave like?** → `spectrum-design-data/docs/s2-docs/components/<category>/<name>.md` (anatomy, states, behaviors, usage); cross-check visuals with `spectrum-css/components/<name>/`
- **Cross-cutting design language (motion timings, focus-ring spec, icon sizing)?** → `spectrum-design-data/docs/s2-docs/designing/*.md`
- **What ttk option / element / state does this need?** → `tcltk/man/mann/ttk_*.n`, `image.n`, `bind.n`
- **How do I verify my change?** → `docs/smoke_testing.md`, then `kitchen-sink.tcl` for visual

The root `CLAUDE.md` has the full orientation if you arrived fresh.
