# spectrum-tk Architecture

> Status: living document. Updated alongside the code; describes what is built and what is intended.

## Goals

Bring the **Adobe Spectrum 2** design system to **Tcl/Tk 9.x**, both as:

1. A **Ttk theme** that re-skins the standard widget set (`ttk::*` and the classic Tk widgets via the option database) so any existing Tk application picks up Spectrum's look-and-feel for free.
2. A library of **Spectrum components** (`spectrum::Button`, `spectrum::Switch`, ...) that don't exist in core Tk, plus richer wrappers around the ones that do.

The design system is the source of truth. Component names, variants, prop names, and visual specifications mirror Adobe's terminology; we do not Tcl-ify them.

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
│  spectrum-vars.tcl (generated from @adobe/spectrum-tokens) │
│  — colors, layout, typography exposed as ::spectrum::var() │
└────────────────────────────────────────────────────────────┘
```

### Phase 1 — Theme foundation

Every standard Tk widget should look like Spectrum without the application doing anything beyond `package require spectrum; spectrum::theme use`. This is implemented in `spectrum.tcl` via the `::spectrum::Theme` class, which subclasses `clam` and re-skins each widget class on theme activation.

Scrollbars deliberately diverge from Spectrum 2 web specs and instead follow the host platform's native look (with arrow buttons): a Windows-style thumb on Windows, a slimmer thumb on macOS, and the clam default on Linux. Spectrum tokens still drive the colors. This is intentional — users are familiar with their platform's scrollbar muscle memory.

- **ttk classes — styled today:** TButton (default + Primary + Accent variants), TLabel, TFrame, TLabelframe, TEntry, TCombobox, TSpinbox, TMenubutton, TNotebook, TProgressbar, TScale, TScrollbar, TSeparator.
- **ttk classes — pending:** TCheckbutton, TRadiobutton, TPanedwindow, TSizegrip, Treeview.
- **Classic widgets** (configured via the option database in `refreshOptions`): partial — Text and Menu are configured today. Pending: Toplevel, Frame, Label, Button, Checkbutton, Radiobutton, Entry, Listbox, Scrollbar, Scale, Spinbox, Menubutton, Message, Canvas.
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

One `oo::abstract` + `oo::configurable` class per `component` field in `@adobe/spectrum-tokens`. Each declares properties matching the tokens for that component (e.g. `-backgroundColorDefault`, `-cornerRadius`), with values resolved from `::spectrum::var(...)` and dark-mode aware.

These are mixed into concrete component classes; they are never instantiated directly. The generator (`gen-spectrum-components.tcl`) emits `spectrum-components.tcl` which is checked in, mirroring the `gen-spectrum-vars.tcl` → `spectrum-vars.tcl` pipeline.

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

```
node_modules/@adobe/spectrum-tokens/src/*.json
       │
       ├── gen-spectrum-vars.tcl       → spectrum-vars.tcl       (checked in)
       │       (colors, layout, typography → ::spectrum::var())
       │
       └── gen-spectrum-components.tcl → spectrum-components.tcl (checked in)
               (per-component-field abstracts → ::spectrum::token::*)
```

Both are regenerated only when bumping `@adobe/spectrum-tokens`. `tclkitsh` is the recommended runner — see the README.

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
├── spectrum.tcl                # Theme entry point + ::spectrum::Theme class
├── spectrum-vars.tcl           # Generated tokens
├── spectrum-components.tcl     # Generated abstract token classes (Phase 2 — planned)
├── gen-spectrum-vars.tcl       # Token → vars generator
├── gen-spectrum-components.tcl # Tokens → abstract classes generator (Phase 2 — planned)
├── pkgIndex.tcl
├── kitchen-sink.tcl            # Visual test harness — every standard Tk/Ttk widget
├── components/                 # Concrete components (Phase 3 — planned)
│   ├── _component.tcl          # ::spectrum::Component base
│   ├── Button.tcl
│   ├── Switch.tcl
│   └── ...
├── docs/
│   ├── architecture.md
│   ├── user_guide.md
│   └── test_strategy.md
└── test/                       # tcltest suites (planned)
```

## Open questions

- RGBA generation strategy: emit `_on_<surface>` variants vs. emit raw RGBA and resolve at runtime. Decide when first needed.
- Whether Phase-2 abstracts should be one-per-token-component or one-per-S2-component (some S2 components like `Button` cover several token-components: `button`, `action-button`, `floating-action-button`).
