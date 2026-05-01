# spectrum-tk Architecture

> Status: living document. Updated alongside the code; describes what is built and what is intended.

## Goals

Bring the **Adobe Spectrum 2** design system to **Tcl/Tk 9.x**, both as:

1. A **Ttk theme** that re-skins the standard widget set (`ttk::*` and the classic Tk widgets via the option database) so any existing Tk application picks up Spectrum's look-and-feel for free.
2. A library of **Spectrum components** (`spectrum::Button`, `spectrum::Switch`, ...) that don't exist in core Tk, plus richer wrappers around the ones that do.

The design system is the source of truth. Component names, variants, prop names, and visual specifications mirror Adobe's terminology; we do not Tcl-ify them.

## Reference materials

Adobe ships the design system as code, not just documentation. Three git submodules under the project root provide the inputs the generators read and the references porting work cross-checks against:

| Submodule | What it provides | Used by |
| --- | --- | --- |
| `spectrum-design-data/` | Tokens (`packages/tokens/src/*.json`), per-component prop schemas (`packages/component-schemas/schemas/components/*.json`), normative spec (`packages/design-data-spec/spec/*.md`), hand-written Spectrum 2 design guidelines (`docs/s2-docs/{fundamentals,designing,components}/*.md`), and an auto-generated flat markdown mirror (`docs/markdown/`) | `gen-spectrum-vars.tcl`, `gen-spectrum-components.tcl`; porting work reads `docs/s2-docs/components/<category>/<name>.md` for anatomy/behaviors/usage and `docs/s2-docs/designing/*.md` for cross-cutting design language |
| `spectrum-css/` | Adobe's CSS implementation, one directory per component with `index.css` + `themes/spectrum-two.css` | Cross-check: read alongside porting work to confirm token-to-state mapping |
| `spectrum-css-workflow-icons/` | 396 workflow icon SVGs at 20×20 (`icons/assets/svg/*.svg`) plus parallel Lit-element wrappers (`icons/assets/components/icon<Name>.{js,d.ts}`) | `gen-spectrum-icons.tcl` (planned) |

`docs/s2-docs/` is the authoritative *design* reference — when a component's *behaviour* (keyboard focus, tooltip-on-hover-with-hidden-label, transition timing) isn't visible in the schema or CSS, this is where it's specified. It supersedes the role `@react-spectrum/s2` previously played in the workflow.

## Layered design

```
┌────────────────────────────────────────────────────────────┐
│  Phase 3 — Concrete components                             │
│  spectrum::Button, spectrum::Switch, spectrum::Tooltip ... │
│  (one file per component; each pairs an oo::class with a   │
│   lowercase command-style alias for idiomatic Tk usage)    │
├────────────────────────────────────────────────────────────┤
│  Phase 2 — OO infrastructure                               │
│  ::spectrum::Component  (oo::abstract; widget-path         │
│    aliasing, <Destroy> binding, unknown delegation)        │
│  ::spectrum::token::*    (oo::abstract + oo::configurable; │
│    one per spectrum-tokens 'component' field — generated)  │
├────────────────────────────────────────────────────────────┤
│  Phase 1 — Theme foundation                                │
│  Spectrum-styled ttk::* widgets and option-database        │
│  configuration for classic Tk widgets. SVG photo factory   │
│  and RGBA blend helper live here.                          │
├────────────────────────────────────────────────────────────┤
│  Tokens                                                    │
│  spectrum-vars.tcl (generated from spectrum-design-data)   │
│  — colors, layout, typography exposed as ::spectrum::var() │
└────────────────────────────────────────────────────────────┘
```

### Phase 1 — Theme foundation

Every standard Tk widget should look like Spectrum without the application doing anything beyond `package require spectrum; spectrum::theme use`. This is implemented in `spectrum.tcl` via the `::spectrum::Theme` class, which subclasses `clam` and re-skins each widget class on theme activation.

Scrollbars deliberately diverge from Spectrum 2 web specs and use a unified **Windows 11-style appearance on every platform** — rounded chevron arrow buttons, a slim rounded-pill thumb, 16px width. Every element is drawn from SVG via `::spectrum::priv::svg_image` and the named-photo `set_image` helper, so dark/light mode swaps recolor in place without rebuilding elements. The four custom elements per orientation (`Spectrum.Vscroll.trough`, `.thumb`, `.uparrow`, `.downarrow`, plus the horizontal variants) replace the clam-derived defaults via custom layouts.

- **ttk classes — styled today:** TButton (default + Primary + Accent variants), TLabel, TFrame, TLabelframe, TEntry, TCombobox, TSpinbox, TMenubutton, TNotebook, TProgressbar, TScale, TCheckbutton, TRadiobutton, TPanedwindow, TSizegrip, Treeview, TScrollbar, TSeparator.
- **ttk classes — pending:** none — Phase 1 ttk coverage is complete.
- **Image elements — implemented:** `Spectrum.Checkbutton.indicator`, `Spectrum.Radiobutton.indicator`, the eight scrollbar elements (`Spectrum.{V,H}scroll.{trough,thumb,uparrow|leftarrow,downarrow|rightarrow}`), the four progressbar elements (`Spectrum.{H,V}progress.{trough,pbar}`), and the three scale elements (`Spectrum.{H,V}scale.trough`, `Spectrum.Scale.slider`). All built from SVG strings, support normal/hover/disabled where applicable, and recolor on dark-mode toggle without re-creating elements.
- **Classic widgets** (configured via the option database in `refreshOptions`): full coverage — Toplevel, Frame, Label, Message, Button, Checkbutton, Radiobutton, Entry, Spinbox, Listbox, Scale, Scrollbar, Menubutton, Canvas, Text, Menu (plus the Combobox popup Listbox). Populated via explicit `*Class.option` patterns at `widgetDefault` priority, plus a small set of global defaults (`*background`, `*foreground`, etc.). `tk_setPalette` is intentionally **not** used: its broad 1-component patterns empirically beat 2-component `*Class.option` patterns in the option-db lookup, and it directly reconfigures every widget bypassing later `option add` calls. Existing widget instances are reconfigured via a tree walk that calls `RefreshWidget` on the root window and any descendant whose class is in the enumerated classic list.
- **Image elements** will be used where solid fills can't reach Spectrum fidelity (e.g. checkbox/radio indicators, switch track, scrollbar thumb shape, focus ring). They are produced from inline SVG via `::spectrum::priv::svg_image`, which caches by content + DPI scaling.

#### Theme activation

`spectrum::theme use` invokes `refreshBindings`, `refreshStyles`, and `refreshOptions` directly. The `<<ThemeChanged>>` virtual-event binding is also registered (on `[winfo class .]`) but is currently not firing reliably — known issue, deferred. Direct invocation guarantees the styles are applied.

### Phase 2 — OO infrastructure

#### `::spectrum::Component`

`oo::abstract`. Wraps a Tk widget path and gives it an OO surface. Pattern:

- The constructor receives a Tk widget path (`.b`). The Tk widget command is renamed into the object's namespace, then an interp alias from `::$path` to `[self]` makes the path callable as the object.
- `<Destroy>` on the path is bound to destroy the object, so when Tk reaps the widget the object follows.
- An `unknown` method delegates anything not matching a method to the underlying Tk command, so `.b configure -text Foo`, `.b state pressed`, etc. continue to work.

#### `::spectrum::token::*` (generated)

One `oo::abstract` + `oo::configurable` class per `component` field in `spectrum-design-data/packages/tokens/src`. Each declares properties matching the tokens for that component (e.g. `-backgroundColorDefault`, `-cornerRadius`), with values resolved from `::spectrum::var(...)` and dark-mode aware.

These are mixed into concrete component classes; they are never instantiated directly. The generator (`gen-spectrum-components.tcl`) emits `spectrum-components.tcl` which is checked in, mirroring the `gen-spectrum-vars.tcl` → `spectrum-vars.tcl` pipeline.

The component prop surface (variants, sizes, boolean states) is **not** in the token JSONs — it lives in `spectrum-design-data/packages/component-schemas/schemas/components/<name>.json`. The generator reads both: tokens for the styling property bag, schemas for the configurable prop names, enums, and defaults.

### Phase 3 — Concrete components

One file per component in `components/`, named verbatim after the Spectrum component (`Button.tcl`, `ActionButton.tcl`, `IllustratedMessage.tcl`).

Three implementation tiers:

- **Direct ttk wrappers** — Button, Checkbox, Radio, TextField, Switch, Tabs, ProgressBar, Slider, ComboBox, Picker, NumberField, SearchField.
- **Composite from `frame`/`toplevel`** — Dialog, Tooltip, Popover, Toast, ContextualHelp, Disclosure, Accordion, Breadcrumbs, Link, Badge, StatusLight, InlineAlert, Avatar, Card, Form, ButtonGroup, Menu.
- **Canvas-drawn customs** — ProgressCircle, Meter, ColorArea/Slider/Wheel/Field/Swatch, RangeSlider, Calendar, DatePicker, DateField, TimeField, Skeleton, TagGroup, SegmentedControl, ListView, CardView, TableView, DropZone, ActionBar.

#### Public API shape

Each concrete component exposes a `TitleCase` `oo::class` and a lowercase command-style alias:

```tcl
spectrum::Button .b -variant accent -text Save   ;# class form
spectrum::button .b -variant accent -text Save   ;# command form (idiomatic Tk)
.b configure -variant primary
pack .b
destroy .b   ;# Tk widget and OO object both cleaned up
```

The lowercase aliases are minted at package-load time by iterating `info class subclasses ::spectrum::Component` — no per-component boilerplate.

## Generation pipeline

Three generators read from git submodules and emit checked-in `.tcl` files. None of the submodules are loaded at runtime — they're reference inputs only.

```
spectrum-design-data/packages/tokens/src/*.json
       │
       ├── gen-spectrum-vars.tcl              → spectrum-vars.tcl       (checked in)
       │       (colors, layout, typography → ::spectrum::var())
       │
       └─┬─ gen-spectrum-components.tcl       → spectrum-components.tcl (checked in)
         │     (per-component-field abstracts → ::spectrum::token::*)
         │
         └─ also reads:
            spectrum-design-data/packages/component-schemas/schemas/components/*.json
              (variants, sizes, boolean states → oo::configurable properties)

spectrum-css-workflow-icons/icons/assets/svg/*.svg
       │
       └── gen-spectrum-icons.tcl             → spectrum-icons.tcl      (checked in)
               (one proc per icon, parameterized on size + color via SVG photo)
```

All three regenerate only when the upstream submodules are bumped. `tclkitsh` is the recommended runner — see the README. To pull upstream updates: `git submodule update --remote --merge`.

### `gen-spectrum-icons.tcl` (planned)

Reads each `S2_Icon_<Name>_20_N.svg` in `spectrum-css-workflow-icons/icons/assets/svg/` and emits one Tcl wrapper per icon.

The model is the Lit-element wrapper from `icons/assets/components/icon<Name>.{js,d.ts}`:

```ts
// icons/assets/components/icon3D.d.ts
export declare const icon3D: ({ width, height, ariaHidden, title, id, focusable }?: {...}) => string | TemplateResult;
```

The Tcl mirror is simpler — no DOM, no a11y attributes (Tk handles those at the widget level). Each generated proc accepts `-size` (default 20, the icon's natural viewBox) and `-color` (default `currentColor`-equivalent: `$::spectrum::var(neutral-content-color-default)` resolved at call time), substitutes them into the SVG body, and returns a Tk photo image via `::spectrum::priv::svg_image` (which caches by content + DPI).

```tcl
spectrum::icon::3D -size 16 -color $::spectrum::var(accent-color-900)
;# → photo image name
```

Naming preserves Spectrum's PascalCase: `S2_Icon_AlertTriangle_20_N.svg` → `::spectrum::icon::AlertTriangle`. Components consume icons by token (e.g. Button reads `spectrum-workflow-icon-size-100` from the layout tokens to pick a size).

## Transparency

Tk widget options (`-background`, `-foreground`, etc.) only accept `#RRGGBB`, no alpha. Spectrum tokens use `rgba()` heavily for overlays, focus rings, scrim, etc. Two complementary tactics:

1. **For ttk image elements and icons** — render via SVG to a photo image. SVGs use `rgba()` directly; Tk's photo image is 32-bit and composites correctly onto whatever sits beneath.
2. **For RGBA used as a flat fill on a known surface** — `::spectrum::priv::blend $rgba $surface` pre-composes RGBA against a solid surface color (typically `gray-100` or `gray-200`) at runtime, yielding an opaque hex Tk can use.

The current `gen-spectrum-vars.tcl` drops RGBA tokens; this will be revisited when the first concrete need arises.

## Animation & state plumbing

Spectrum specifies short transitions (~130ms) for hover/press/focus and continuous animation for indeterminate progress and skeletons. ttk does not animate state changes natively. Plumbing:

- `::spectrum::priv::animate` — minimal helper that schedules `after` ticks to interpolate between two photo images (for crossfades) or to re-rasterize an SVG with parameter changes (for indeterminate spinners, skeleton shimmer).
- Per-state image elements use ttk's standard state map; transitions are an opt-in layer on top.

## File layout

```
spectrum-tk/
├── spectrum.tcl                  # Theme entry point + ::spectrum::Theme class
├── spectrum-vars.tcl             # Generated tokens
├── spectrum-components.tcl       # Generated abstract token classes (Phase 2 — planned)
├── spectrum-icons.tcl            # Generated icon procedures (planned)
├── gen-spectrum-vars.tcl         # Token JSON → vars generator
├── gen-spectrum-components.tcl   # Token JSON + component schemas → abstract classes (planned)
├── gen-spectrum-icons.tcl        # Icon SVG → Tcl wrapper generator (planned)
├── pkgIndex.tcl
├── kitchen-sink.tcl              # Visual test harness — every standard Tk/Ttk widget
├── components/                   # Concrete components (Phase 3 — planned)
│   ├── _component.tcl            # ::spectrum::Component base
│   ├── Button.tcl
│   ├── Switch.tcl
│   └── ...
├── docs/
│   ├── architecture.md
│   ├── user_guide.md
│   ├── test_strategy.md
│   ├── smoke_testing.md
│   └── next_steps.md
├── test/                         # tcltest suites (planned)
├── spectrum-design-data/         # submodule — tokens, component schemas, design-data spec
├── spectrum-css/                 # submodule — Adobe's CSS reference implementation
├── spectrum-css-workflow-icons/  # submodule — workflow-icon SVGs + Lit wrappers
└── tcltk/                        # local copy of Tcl/Tk 9.x man pages
```

## Open questions

- RGBA generation strategy: emit `_on_<surface>` variants vs. emit raw RGBA and resolve at runtime. Decide when first needed.
- Whether Phase-2 abstracts should be one-per-token-component or one-per-spectrum-design-data-component (some spectrum-design-data components like `Button` may cover several token-components: `button`, `action-button`, `floating-action-button`).
