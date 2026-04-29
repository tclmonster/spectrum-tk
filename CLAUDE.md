# spectrum-tk — orientation for Claude

This file is the front door. It tells you what the project is, where authoritative information lives, and how to operate. Detailed material is in `docs/` — link out, don't duplicate.

## What this project is

A Ttk theme **and** a component library for **Tcl/Tk 9.x** that re-skins the standard widget set in [Adobe Spectrum 2](https://spectrum.adobe.com/) and adds the Spectrum components Tk doesn't have. The design system is the source of truth — names, variants, prop names, and visual specs mirror Adobe's terminology. Do not Tcl-ify them.

Required runtime: **Tcl/Tk 9.x** (for `oo::configurable`, `oo::abstract`, and built-in SVG via `$::tk::svgFmt`).

For the layered architecture (theme foundation → OO infrastructure → concrete components), the file layout, and the generation pipeline, read [docs/architecture.md](docs/architecture.md). For phase-by-phase status, the same file's component table is the live reference.

## The three reference sources

When you need to know something Spectrum-related, check these in this order. **Do not invent — look it up.**

### 1. `node_modules/@adobe/spectrum-tokens/src/*.json` — design tokens (source of truth)

JSON files keyed by token name. Each token has:
- `value` (literal `rgb(...)`, `12px`, etc.) **or** `sets` keyed by mode (`light`, `dark`, `wireframe`, `desktop`).
- `component` field that groups tokens by Spectrum component (`button`, `action-button`, `accordion`, ...). 92 components are defined; many components share tokens.

Files:
- `color-component.json`, `color-aliases.json`, `color-palette.json`, `semantic-color-palette.json` — colours.
- `layout.json`, `layout-component.json` — sizes, spacing, corners, padding.
- `typography.json` — font families, sizes, weights.
- `icons.json` — icon-related tokens.

Read with `jq`/Node when exploring. For everyday use, the same data is already exposed at runtime via `::spectrum::var(token-name)` (see `spectrum-vars.tcl`, regenerated from these JSONs by `gen-spectrum-vars.tcl`).

> The `spectrum-design-data` MCP returns `total: 0` components — do not rely on it. Use the JSON files directly.

### 2. `node_modules/@react-spectrum/s2/src/*.tsx` — reference implementations

Adobe's Spectrum 2 component library in React/TypeScript. Use it to answer:
- "What states does this component have?" (e.g. `isDisabled`, `isInvalid`, `isQuiet`)
- "What variants exist?" (e.g. Button has `accent`, `primary`, `secondary`, `negative`)
- "What does focus / hover / press look like behaviorally?"
- "What sub-elements does this component compose?"

One file per component, named verbatim (`Button.tsx`, `IllustratedMessage.tsx`, `ToggleButton.tsx`). Page-by-page S2 docs are also accessible via the `react-spectrum-s2` MCP (`list_s2_pages`, `get_s2_page`).

### 3. `tcltk/man/{man1,man3,mann}/` — Tcl/Tk 9.x man pages

The authoritative reference for the Tcl/Tk APIs we are mapping Spectrum onto.

- `mann/` — Tcl/Tk **commands** (where you spend most of your time):
  - `ttk_*.n` — every ttk widget and the styling system. `ttk_style.n`, `ttk_image.n`, `ttk_widget.n`, `ttk_button.n`, etc.
  - `image.n`, `photo.n`, `tk_svgFmt.n` — image creation, SVG rasterization, DPI-aware scaling.
  - `bind.n`, `bindtags.n`, `event.n` — event handling and propagation.
  - `canvas.n` — for the Phase-3 components that draw their own visuals (ProgressCircle, ColorWheel, etc.).
  - `font.n`, `option.n` — font management, option database (used by classic widgets).
- `man3/` — Tcl/Tk C API. Rarely needed unless extending with `cffi`.
- `man1/` — `wish.1`, `tclsh.1`. Reference for the runtimes themselves.

When porting a Spectrum component, the typical question is: "what ttk element / state / layout primitive maps to this Spectrum behaviour?" — the answer is in `mann/`. Open it, read it; don't guess.

## Working through a port

Rough sequence when adding a Spectrum component or restyling a ttk class:

1. **Identify tokens.** Find the relevant entries in `@adobe/spectrum-tokens/src/*.json` or in `::spectrum::var()`. Use them — never hardcode colors or sizes.
2. **Read the spec.** Open the matching `.tsx` in `@react-spectrum/s2/src/` to see states, variants, and composition.
3. **Find the Tk primitive.** Open the relevant `tcltk/man/mann/*.n` to see what ttk gives you and what you need to extend with image elements / custom layouts.
4. **Implement** in the right file (`spectrum.tcl` for theme work, `components/Foo.tcl` for concrete components — see [docs/architecture.md](docs/architecture.md)).
5. **Smoke test** before committing — see [docs/smoke_testing.md](docs/smoke_testing.md).
6. **Update the docs** that describe what shipped — `docs/architecture.md` coverage tables and `docs/user_guide.md` status table.
7. **Commit** with a focused message in the style of `git log --oneline`. No Claude attribution trailers.

## Smoke testing

`tclkit*.exe` on Windows is a GUI executable — `puts stdout` does not reach the launching shell. Smoke scripts log to a file and wrap their body in `try ... on error ... finally close+exit`. Full pattern, introspection commands, and dark-mode toggle recipe in [docs/smoke_testing.md](docs/smoke_testing.md).

For visual inspection, run `kitchen-sink.tcl` directly in `tclkit` — it shows one of every standard widget and has a dark-mode toggle in the header.

## Conventions

- **Spectrum terminology, never Tk terminology.** Use *component*, *variant*, etc. — not *widget*, *megawidget*. Concrete component file names match Spectrum's PascalCase verbatim (`Button.tcl`, `IllustratedMessage.tcl`).
- **Tokens, not literals.** `$::spectrum::var(gray-100)`, not `#E9E9E9`.
- **Docs are kept current.** Whenever a chunk lands, update `docs/architecture.md` and `docs/user_guide.md` so they describe what shipped — not what was planned.
- **Tests are simple and event-driven.** `tcltest` + `event generate <Button-1>` / `<Key-space>` / `<FocusIn>`. No mocking, no screenshot diffing. See [docs/test_strategy.md](docs/test_strategy.md).
- **`tclkitsh` for non-Tk scripts** (e.g. `gen-spectrum-vars.tcl` — no event loop needed). **`tclkit`** for anything that touches Tk.
- **Commits do not include Claude / Anthropic attribution.** No `Co-Authored-By: Claude...` or "Generated with Claude Code" trailers.
- **Smoke wrappers (`_`-prefixed) never get committed.** Clean them up.

## Where things live

- `spectrum.tcl` — Theme entry point, `::spectrum::Theme` class, all per-class `Refresh*` methods, SVG helpers (`svg_image`, `set_image`, `checkbox_svg`, `radio_svg`, `scrollbar_*_svg`).
- `spectrum-vars.tcl` — generated tokens. Regenerate with `tclkitsh gen-spectrum-vars.tcl > spectrum-vars.tcl`.
- `kitchen-sink.tcl` — visual test harness covering every standard widget.
- `docs/` — architecture, user guide, test strategy, smoke testing, next steps.
- `components/` — concrete Phase-3 components (planned, not yet present).
- `node_modules/` — Adobe Spectrum tokens + `@react-spectrum/s2` reference source. Reference-only; never imported at runtime.
- `tcltk/` — local copy of Tcl/Tk 9.x man pages.
- `~/.claude/projects/.../memory/MEMORY.md` — auto-memory entries (terminology, scrollbar policy, smoke-testing approach, etc.). Loaded automatically.
