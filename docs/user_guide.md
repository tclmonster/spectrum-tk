# spectrum-tk User Guide

> Status: living document. Sections marked _Planned_ describe intended behaviour that is not yet implemented.

`spectrum-tk` is a Tcl/Tk 9.x library that re-skins your application in Adobe's [Spectrum 2](https://spectrum.adobe.com/) design system and provides a growing set of Spectrum components on top.

## Installation

```sh
git clone https://github.com/tclmonster/spectrum-tk.git
cd spectrum-tk
git submodule update --init --recursive   # one-time, only needed to (re)generate tokens/icons
```

`spectrum-tk` requires **Tcl/Tk 9.x** (for built-in SVG support and `oo::configurable`). A portable `tclkit` runner is linked from the README.

The submodules (`spectrum-design-data`, `spectrum-css`, `spectrum-css-workflow-icons`) provide tokens, component schemas, and icon SVGs upstream — they are inputs to the generators, not runtime dependencies. If you only consume `spectrum-tk` via `package require spectrum`, you don't need them.

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

| Surface | Status |
| --- | --- |
| Theme foundation: full ttk coverage (TButton + variants, TLabel, TFrame, TLabelframe, TEntry, TCombobox, TSpinbox, TMenubutton, TNotebook, TProgressbar, TScale, TCheckbutton, TRadiobutton, TPanedwindow, TSizegrip, Treeview, TScrollbar, TSeparator) | Implemented |
| Theme foundation: SVG indicator elements for Checkbutton + Radiobutton with dark-mode redraw | Implemented |
| Theme foundation: SVG element scrollbar (Win11-style, cross-platform) | Implemented |
| Theme foundation: classic widget option database (Toplevel, Frame, Label, Message, Button, Checkbutton, Radiobutton, Entry, Spinbox, Listbox, Scale, Scrollbar, Menubutton, Canvas, Text, Menu) | Implemented |
| SVG photo factory (`::spectrum::priv::svg_image`) | Implemented |
| Concrete `spectrum::*` components | Planned |

Scrollbars use a unified Windows 11-style appearance on every platform — rounded chevron arrows and a slim rounded-pill thumb, 16px wide, drawn from SVG and recolored from Spectrum tokens.

This table is updated as work lands.

## Visual testing

`kitchen-sink.tcl` at the project root renders one of every standard Tk and Ttk widget, grouped into Buttons / Inputs / Indicators / Selection / Containers / Canvas tabs. Run it with any Tcl/Tk 9.x `wish`:

```sh
./tclkit-9.0.3-<platform> kitchen-sink.tcl
```

There's a "Toggle dark mode" button in the header for inspecting both modes without restarting.

## Customisation

Spectrum tokens are exposed in the `::spectrum::var(...)` array — colours, layout sizes, typography. Read them; do not write them (mutation will be silently overwritten on theme refresh).

```tcl
ttk::label .greeting \
    -text "Hello" \
    -foreground $::spectrum::var(accent-content-color-default)
```

Application-specific styles can extend the theme by adding new ttk styles in their own `<<ThemeChanged>>` handler.

## Regenerating tokens

Only needed when bumping the `spectrum-design-data` submodule:

```sh
git submodule update --remote --merge spectrum-design-data
./tclkitsh-9.0.3-<platform> gen-spectrum-vars.tcl > spectrum-vars.tcl
```

See the README for prebuilt `tclkitsh` binaries.
