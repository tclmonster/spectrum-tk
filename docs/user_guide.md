# spectrum-tk User Guide

> Status: living document. Sections marked _Planned_ describe intended behaviour that is not yet implemented.

`spectrum-tk` is a Tcl/Tk 9.x library that re-skins your application in Adobe's [Spectrum 2](https://spectrum.adobe.com/) design system and provides a growing set of Spectrum components on top.

## Installation

```sh
git clone https://github.com/tclmonster/spectrum-tk.git
cd spectrum-tk
npm install   # one-time, only needed to (re)generate tokens
```

`spectrum-tk` requires **Tcl/Tk 9.x** (for built-in SVG support and `oo::configurable`). A portable `tclkit` runner is linked from the README.

## Quick start

```tcl
lappend auto_path /path/to/spectrum-tk
package require spectrum
spectrum::theme use
```

That's it — every standard `ttk::*` widget and most classic Tk widgets in your application are now styled to match Spectrum, in light or dark mode based on the host OS.

## Theme activation

`spectrum::theme use` activates the Spectrum theme for the current application. The theme:

- Detects OS-level dark/light mode (Windows registry, macOS `defaults`, Linux freedesktop portal) and configures accordingly.
- Selects Spectrum-appropriate fonts from the system (Source Sans Pro → Segoe UI → ... fallback chain).
- Re-styles every `ttk::*` widget class.
- Updates the option database so classic Tk widgets (`text`, `listbox`, `menu`, ...) inherit Spectrum colours and fonts.

The theme refreshes on `<<ThemeChanged>>`, so you can switch themes at runtime and Spectrum will re-apply its styles.

### Forcing a mode

```tcl
set ::spectrum::var(darkmode) 1   ;# force dark
event generate . <<ThemeChanged>>
```

## Components _(Planned — see [architecture.md](architecture.md) for the build plan)_

Each Spectrum component will be available under two equivalent forms:

```tcl
spectrum::Button .b -variant accent -text Save   ;# class form
spectrum::button .b -variant accent -text Save   ;# command form
```

The command form is the idiomatic Tk style and composes directly with `pack`/`grid`/`place`.

### Component status

| Spectrum component | Status |
| --- | --- |
| Theme foundation (ttk + classic widgets) | In progress |
| Button | Planned |
| Switch | Planned |
| TextField | Planned |
| Checkbox | Planned |
| Tooltip | Planned |
| _(everything else from the S2 catalog)_ | Planned |

This table is updated as components land.

## Customisation

Spectrum tokens are exposed in the `::spectrum::var(...)` array — colours, layout sizes, typography. Read them; do not write them (mutation will be silently overwritten on theme refresh).

```tcl
ttk::label .greeting \
    -text "Hello" \
    -foreground $::spectrum::var(accent-content-color-default)
```

Application-specific styles can extend the theme by adding new ttk styles in their own `<<ThemeChanged>>` handler.

## Regenerating tokens

Only needed when bumping `@adobe/spectrum-tokens`:

```sh
npm install
./tclkitsh-9.0.3-<platform> gen-spectrum-vars.tcl > spectrum-vars.tcl
```

See the README for prebuilt `tclkitsh` binaries.
