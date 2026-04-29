# spectrum-tk

> **Early alpha.** This project is in an exploratory phase — APIs, file layout, and styling are all subject to change without notice. Expect rough edges and missing widgets.

A Ttk theme for Tcl/Tk that follows [Adobe's Spectrum 2](https://spectrum.adobe.com/) design system.

The theme consumes Adobe's design tokens (vendored as a git submodule from [`spectrum-design-data`](https://github.com/adobe/spectrum-design-data)) and converts them into Tcl variables that drive a Ttk theme implementation. It targets **Tcl/Tk 9.x**, which provides built-in SVG support — useful for Spectrum's icon and illustration set.

## Repository Layout

| File / directory | Purpose |
| --- | --- |
| `spectrum.tcl` | Theme entry point. Defines fonts, dark-mode detection, and Ttk styles. |
| `spectrum-vars.tcl` | Generated variable definitions (colors, layout, typography). Do not edit by hand. |
| `gen-spectrum-vars.tcl` | Reads Adobe's JSON tokens from `spectrum-design-data/` and emits `spectrum-vars.tcl`. |
| `pkgIndex.tcl` | Standard Tcl package index. |
| `spectrum-design-data/` | Submodule. Tokens, component schemas, design-data spec, design guidelines. |
| `spectrum-css/` | Submodule. Adobe's CSS reference implementation. |
| `spectrum-css-workflow-icons/` | Submodule. Workflow icon SVGs and Lit wrappers. |

## Requirements

- Tcl/Tk **9.x**
- `git` with submodule support (only required if you intend to regenerate tokens or icons)

## Cloning

```sh
git clone https://github.com/tclmonster/spectrum-tk.git
cd spectrum-tk
git submodule update --init --recursive   # only needed to (re)generate tokens or icons
```

If you only intend to consume `spectrum-tk` via `package require spectrum`, the submodules are unnecessary — the generated `spectrum-vars.tcl` is checked in.

## Usage

```tcl
lappend auto_path /path/to/spectrum-tk
package require spectrum
spectrum::theme use
```

## Regenerating `spectrum-vars.tcl`

The generated file is checked in, so you only need this when bumping the upstream design tokens.

```sh
git submodule update --remote --merge spectrum-design-data
tclsh gen-spectrum-vars.tcl       # any Tcl 9.x interpreter with the tjson package
```

A portable Tcl 9.x shell (no Tk, no event loop) is convenient for running the
generator. Prebuilt `tclkitsh` binaries are available here:

- [Windows (x86_64)](https://github.com/tclmonster/kitcreator/releases/download/1.1.1/tclkitsh-9.0.3-x86_64-w64-mingw32.exe)
- [macOS (arm64)](https://github.com/tclmonster/kitcreator/releases/download/1.1.1/tclkitsh-9.0.3-arm64-apple-darwin23.6.0)
- [Linux (x86_64)](https://github.com/tclmonster/kitcreator/releases/download/1.1.1/tclkitsh-9.0.3-x86_64-linux-gnu)

```sh
./tclkitsh-9.0.3-<platform> gen-spectrum-vars.tcl > spectrum-vars.tcl
```

## License

BSD-3-Clause — see [LICENSE](LICENSE).

The bundled Adobe Spectrum design tokens are licensed under Apache-2.0; see the
generated header in `spectrum-vars.tcl` for attribution.
