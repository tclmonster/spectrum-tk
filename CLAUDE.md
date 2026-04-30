# spectrum-tk — orientation for Claude

This file is the front door. It tells you what the project is, where authoritative information lives, and how to operate. Detailed material is in `docs/` — link out, don't duplicate.

## What this project is

A Ttk theme **and** a component library for **Tcl/Tk 9.x** that re-skins the standard widget set in [Adobe Spectrum 2](https://spectrum.adobe.com/) and adds the Spectrum components Tk doesn't have. The design system is the source of truth — names, variants, prop names, and visual specs mirror Adobe's terminology. Do not Tcl-ify them.

**Spectrum 2 — not Spectrum 1.** spectrum-tk targets Spectrum 2 (S2) exclusively. The submodules and reference files often contain both eras side by side (e.g. `spectrum-css` ships `themes/spectrum.css` for Spectrum 1 and `themes/spectrum-two.css` for Spectrum 2; older `@react-spectrum/v3` predates S2). Always read the S2 sources — `themes/spectrum-two.css`, `docs/s2-docs/`, the `spectrum-design-data` token JSON (which is S2-native). Ignore Spectrum 1 references unless explicitly cross-checking what changed.

Required runtime: **Tcl/Tk 9.x** (for `oo::configurable`, `oo::abstract`, and built-in SVG via `$::tk::svgFmt`).

For the layered architecture (theme foundation → OO infrastructure → concrete components), the file layout, and the generation pipeline, read [docs/architecture.md](docs/architecture.md). For phase-by-phase status, the same file's component table is the live reference.

## The four reference sources

When you need to know something Spectrum-related, check these in this order. **Do not invent — look it up.**

All four live as **git submodules** under the project root. Initialize them with `git submodule update --init --recursive`. They are reference-only — never imported at runtime; the generators read them and emit checked-in `.tcl` files.

> **Preferred entry point: the `s2-docs` MCP server.** Before grepping through `spectrum-design-data/docs/`, query the `s2-docs` MCP tools (`mcp__s2-docs__list-s2-components`, `mcp__s2-docs__get-s2-component`, `mcp__s2-docs__search-s2-docs`, `mcp__s2-docs__find-s2-component-by-use-case`, `mcp__s2-docs__get-s2-stats`). Per `spectrum-design-data/docs/s2-docs/README.md` this is the recommended way to surface S2 documentation. It returns the same hand-written `s2-docs/` content as the files but pre-indexed for component lookup, category browsing, and full-text search. Fall back to direct file reads for anything outside the MCP's scope (token JSON, component schemas, spectrum-css). README.md has the setup command.

### 1. `spectrum-design-data/packages/tokens/src/*.json` — design tokens (source of truth)

JSON files keyed by token name. Each token has:
- `value` (literal `rgb(...)`, `12px`, etc.) **or** `sets` keyed by mode (`light`, `dark`, `wireframe`, `desktop`).
- `component` field that groups tokens by Spectrum component (`button`, `action-button`, `accordion`, ...). 92 components are defined; many components share tokens.

Files:
- `color-component.json`, `color-aliases.json`, `color-palette.json`, `semantic-color-palette.json` — colours.
- `layout.json`, `layout-component.json` — sizes, spacing, corners, padding.
- `typography.json` — font families, sizes, weights.
- `icons.json` — icon-related tokens.

The same data is already exposed at runtime via `::spectrum::var(token-name)` (see `spectrum-vars.tcl`, regenerated from these JSONs by `gen-spectrum-vars.tcl`).

The `spectrum-design-data` repository **also** contains:

- `packages/component-schemas/schemas/components/*.json` — **per-component prop schemas** (variants, sizes, states, booleans). 80 components. This is the canonical surface for Phase-2 token classes and Phase-3 component constructors. Each file has `properties.<prop>.enum` / `default` for variants, `meta.category` and `meta.documentationUrl` for grouping.
- `docs/s2-docs/` — Adobe's **hand-written Spectrum 2 design guidelines** in markdown. The most useful directory for porting work:
  - `fundamentals/{introduction,principles,home}.md` — Spectrum 2 intro and design principles.
  - `designing/*.md` — design language fundamentals: `colors`, `grays`, `typography-fundamentals`, `fonts`, `spacing`, `motion`, `states`, `attention-hierarchy`, `icon-fundamentals`, `using-icons`, `illustrations`, `object-styles`, `containers`, `background-layers`, `brand`, plus the `app-frame-*` files. Read these for spec-level details that schemas don't capture (e.g. motion durations, focus ring offset, icon sizing rules).
  - `components/{actions,containers,feedback,inputs,navigation,status}/<name>.md` — per-component design guidance: overview, anatomy, prop table, states, behaviors (keyboard focus, tooltip, cursor style, etc.), usage guidelines, do's and don'ts, related components. **This replaces the role `@react-spectrum/s2` played for behavioral specs** — read it when you need to know *how* a component should behave, not just *what* its prop surface is.
  - `developing/developer-overview.md`, `support/` — supplementary.
- `docs/markdown/` — **auto-generated** flat markdown mirror of schemas + tokens, used by Adobe's 11ty docs site and an internal chatbot. Less verbose than `s2-docs/` but tied directly to the JSON. Useful as a quick prop-table lookup or for grepping across all components in one file tree:
  - `components/<name>.md` — schema → table.
  - `tokens/`, `pages/`, `registry/` — generated token/page/registry references.
  - Marked **DO NOT EDIT** upstream — read-only for us.
- `packages/design-data-spec/spec/*.md` — the **normative specification** for token format, taxonomy, cascade, dimensions, manifest, diff, query, evolution. Read when designing the generators or working through token-resolution edge cases (e.g. `cascade.md`, `token-format.md`).
- `packages/design-system-registry/` — registry-level metadata (component IDs, platform extensions); rarely needed for spectrum-tk.

### 2. `spectrum-css/components/<name>/` — reference implementations

Adobe's Spectrum 2 components implemented in plain CSS. Use it to **cross-check our implementation** — what tokens go where, what selectors react to what state, what the visual primitives are.

Each component is a directory: `index.css` (token wiring + selectors, with Spectrum 1 defaults), `themes/spectrum-two.css` (the Spectrum 2 override layer — token values that supersede the index.css defaults), `themes/spectrum.css` (Spectrum 1 — **ignore unless reasoning about what S2 changed**), `stories/`, `dist/`, `package.json`. The effective S2 value for a token is the `themes/spectrum-two.css` override if present, otherwise the `index.css` default. Component directory names are lowercase Spectrum names (`button`, `actionbutton`, `alertbanner`, `combobox`, ...). Note: directory names drop hyphens — the schema's `action-button.json` corresponds to `actionbutton/`.

Why prefer this over a React implementation: spectrum-css is **declarative** — selectors map directly to states (`:hover`, `[disabled]`, `.is-pressed`), tokens are CSS custom properties resolved literally, no JSX behavioural layer to mentally peel off. We may revisit `@react-spectrum/s2` later for behaviour specs not encoded in CSS, but for now spectrum-css is the cross-check.

### 3. `spectrum-css-workflow-icons/icons/assets/` — workflow icons

Adobe's Spectrum workflow icon library — 396 icons at 20×20 with `viewBox="0 0 20 20"` and `fill="currentColor"` (or `fill="var(--iconPrimary, #222)"` in the source SVG). Two parallel forms:

- `svg/S2_Icon_<Name>_20_N.svg` — raw SVG files. Direct input to `gen-spectrum-icons.tcl` (planned — see architecture.md).
- `components/icon<Name>.{js,d.ts}` — Lit-element wrappers, one per icon, parameterized on `{ width, height, ariaHidden, title, id, focusable }`. The `.d.ts` defines the public surface — useful as the model for the Tcl wrapper signature (we map `width`/`height` to a single `-size` and inherit color from the parent widget).
- `manifest.json` — flat list of every SVG and component file.

`gen-spectrum-icons.tcl` will mirror the `gen-spectrum-vars.tcl` pattern: read every SVG, emit `spectrum-icons.tcl` with a generated proc (or `oo::class`) per icon that produces a Tk photo via `::spectrum::priv::svg_image`, parameterized on size and color.

### 4. `tcltk/man/{man1,man3,mann}/` — Tcl/Tk 9.x man pages

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

1. **Identify tokens.** Find the relevant entries in `spectrum-design-data/packages/tokens/src/*.json` or in `::spectrum::var()`. Use them — never hardcode colors or sizes.
2. **Read the schema.** Open `spectrum-design-data/packages/component-schemas/schemas/components/<name>.json` for the canonical prop surface (variants, sizes, states, booleans). The same prop table also appears in `docs/markdown/components/<name>.md` if you prefer markdown.
3. **Read the design guidelines.** Start with the `s2-docs` MCP (`mcp__s2-docs__get-s2-component`, `mcp__s2-docs__search-s2-docs`) for anatomy, behaviors (keyboard focus, tooltip, cursor, transitions), usage guidance, and per-prop description. Fall back to the matching `spectrum-design-data/docs/s2-docs/components/<category>/<name>.md` if the MCP is unavailable. For cross-cutting design questions (focus ring spec, motion durations, icon sizing), read the relevant `spectrum-design-data/docs/s2-docs/designing/*.md`.
4. **Cross-check visuals.** Look at `spectrum-css/components/<name>/index.css` and `themes/spectrum-two.css` to see exactly which tokens map to which selectors and states.
5. **Find the Tk primitive.** Open the relevant `tcltk/man/mann/*.n` to see what ttk gives you and what you need to extend with image elements / custom layouts.
6. **Implement** in the right file (`spectrum.tcl` for theme work, `components/Foo.tcl` for concrete components — see [docs/architecture.md](docs/architecture.md)).
7. **Smoke test** before committing — see [docs/smoke_testing.md](docs/smoke_testing.md).
8. **Update the docs** that describe what shipped — `docs/architecture.md` coverage tables and `docs/user_guide.md` status table.
9. **Commit** with a focused message in the style of `git log --oneline`. No Claude attribution trailers.

## Smoke testing

`tclkit*.exe` on Windows is a GUI executable — `puts stdout` does not reach the launching shell. Smoke scripts log to a file and wrap their body in `try ... on error ... finally close+exit`. Full pattern, introspection commands, and dark-mode toggle recipe in [docs/smoke_testing.md](docs/smoke_testing.md).

For visual inspection, run `kitchen-sink.tcl` directly in `tclkit` — it shows one of every standard widget and has a dark-mode toggle in the header.

## Conventions

- **Spectrum 2, never Spectrum 1.** Tokens, components, prop names, visual specs all come from S2 sources. When a reference file has both eras, read the S2 layer (`themes/spectrum-two.css`, `docs/s2-docs/`).
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
- `spectrum-icons.tcl` — generated icon procedures (planned; from `gen-spectrum-icons.tcl`).
- `kitchen-sink.tcl` — visual test harness covering every standard widget.
- `docs/` — architecture, user guide, test strategy, smoke testing, next steps.
- `components/` — concrete Phase-3 components (planned, not yet present).
- `spectrum-design-data/` — submodule. Tokens, component schemas, design-data spec. Reference-only.
- `spectrum-css/` — submodule. Adobe's CSS implementation; cross-check our styling against it.
- `spectrum-css-workflow-icons/` — submodule. Workflow-icon SVGs and Lit wrappers; input to `gen-spectrum-icons.tcl`.
- `tcltk/` — local copy of Tcl/Tk 9.x man pages.
- `~/.claude/projects/.../memory/MEMORY.md` — auto-memory entries (terminology, scrollbar policy, smoke-testing approach, etc.). Loaded automatically.
