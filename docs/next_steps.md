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

ttk coverage is **done**. Two pieces left:

### Classic widget option database

`refreshOptions` in `spectrum.tcl` currently configures only `Text`, `Menu`, and the combobox popup `Listbox` (via `RefreshCombobox`). Plus `tk_setPalette` covers some basics. To make non-ttk widgets visually consistent with the theme:

| Classic widget | Option-database keys to set |
| --- | --- |
| `Toplevel` | `*Toplevel.background` |
| `Frame` | `*Frame.background` |
| `Label` | `*Label.background`, `*Label.foreground`, `*Label.font` |
| `Button` | bg/fg/activeBackground/activeForeground/highlightThickness/font |
| `Checkbutton`, `Radiobutton` | bg/fg/selectColor/activeBackground/font |
| `Entry` | `*Entry.background`, `*Entry.foreground`, `*Entry.insertBackground`, `*Entry.relief`, `*Entry.borderWidth` |
| `Listbox` | bg/fg/selectBackground/selectForeground/borderWidth/highlightThickness |
| `Scrollbar` (classic) | troughColor/background/activeBackground (legacy widget; few apps still use it) |
| `Scale` (classic) | troughColor/sliderRelief/font |
| `Spinbox` (classic) | bg/fg/buttonBackground |
| `Menubutton` (classic) | bg/fg/activeBackground/activeForeground |
| `Message` | background/foreground/font |
| `Canvas` | background/highlightThickness |

The `RefreshWidget` helper at the bottom of `spectrum.tcl` already walks the widget tree and re-applies option values to existing instances — when expanding `refreshOptions`, also expand the `switch` in `refreshOptions` that selects which classes to call `RefreshWidget` on (currently only `Menu - Text`).

### RGBA token handling

`gen-spectrum-vars.tcl` currently drops every token whose value is `rgba(...)`. For Phase 3 components that need overlays, focus rings, scrim, or hover tints, a path forward is needed. See architecture.md §Transparency. Implementation is deferred until the first concrete need arises (likely focus ring on Button or Toast/Popover).

---

## Phase 2 — OO infrastructure

Not started. Three artifacts need to land here:

### `components/_component.tcl` — `::spectrum::Component`

`oo::abstract` base. Wraps a Tk widget path and gives it an OO surface: rename the widget command into the object's namespace, `interp alias ::$path` to `[self]`, bind `<Destroy>` for cleanup, `unknown` method delegates to the underlying Tk command. Pattern is in the project memory and discussed in architecture.md §Phase 2.

### `gen-spectrum-components.tcl` → `spectrum-components.tcl`

Mirror of `gen-spectrum-vars.tcl`. Reads the same JSONs but groups tokens by `component` field (92 components — see architecture.md). For each, emits an `oo::abstract create ::spectrum::token::ComponentName { ... }` class using `oo::configurable` properties, where each property maps to a token name (camelCase). The generated file is checked in. Run with `tclkitsh`.

### Lowercase command-style aliases

After all concrete component files are sourced, sweep `info class subclasses ::spectrum::Component` and emit a lowercase command for each (`spectrum::Button` → `spectrum::button`). The lowercase form composes idiomatically with `pack`/`grid`/`place`. Single sweep at package init time.

---

## Phase 3 — Concrete components

Not started. Recommended start order (proven mechanism, then breadth):

1. **Button** — direct ttk wrapper. Establishes the `Component` pattern + variant prop mapping (`-variant accent|primary|secondary|negative`).
2. **Switch** — image-element-driven; reuses the SVG photo factory pattern from Checkbutton.
3. **TextField** — TEntry wrapper plus floating label, validation/help text composition.
4. **Checkbox** — already has the indicator element; the concrete class wires up `-isIndeterminate` and the label.
5. **Tooltip** — first transient `toplevel` component; sets the pattern for Popover, Toast, ContextualHelp.

Then iterate by Spectrum's catalog. The full list of S2 components is in `node_modules/@react-spectrum/s2/src/`; refer to that source plus the `react-spectrum-s2` MCP for behavior specs. Tier breakdown (direct ttk / composite / canvas-drawn) is in architecture.md §Phase 3.

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

- **Where does this token come from?** → `node_modules/@adobe/spectrum-tokens/src/*.json`
- **What does this component look like / behave like?** → `node_modules/@react-spectrum/s2/src/*.tsx`
- **What ttk option / element / state does this need?** → `tcltk/man/mann/ttk_*.n`, `image.n`, `bind.n`
- **How do I verify my change?** → `docs/smoke_testing.md`, then `kitchen-sink.tcl` for visual

The root `CLAUDE.md` has the full orientation if you arrived fresh.
