# spectrum-tk Smoke Testing

> Status: living document. Updated as the smoke-testing pattern evolves.

This is the lightweight pattern we use to verify theme changes load, styles apply, image elements register, and dark-mode swaps don't crash — *before* committing a chunk. Smoke tests are deliberately **simple and disposable**. They are not the project's automated test suite (that lives in `test/`, see [test_strategy.md](test_strategy.md)).

## Why we need a special pattern

`tclkit*.exe` on Windows is a GUI executable with no console attached. `puts stdout` and `puts stderr` from a script do **not** reach the launching `bash` / PowerShell shell — the script appears to run silently and may exit with status 1 on error without any visible diagnostic.

Smoke scripts therefore log to a **file** and wrap their body in `try ... on error ... finally close+exit`. After running, we read the log file from the shell.

## The pattern

Create a file at the project root (named with a leading `_` so it is obviously temporary and easy to clean up):

```tcl
# _ks-smoke.tcl
set log [open [file normalize ./_ks-smoke.log] w]
try {
    source kitchen-sink.tcl     ;# or any other entry point under test
    update                       ;# flush pending events so callbacks fire

    # ... assertions, written with `puts $log ...` ...

    puts $log OK
} on error {res opts} {
    puts $log "ERROR: $res"
    puts $log [dict get $opts -errorinfo]
} finally {
    close $log
    exit 0
}
```

Run it and read the log:

```sh
rm -f _ks-smoke.log
./tclkit-9.0.3-x86_64-w64-mingw32.exe _ks-smoke.tcl
cat _ks-smoke.log
```

After the chunk lands, **delete the smoke wrapper and its log**:

```sh
rm -f _ks-smoke.tcl _ks-smoke.log
```

Smoke wrappers do not belong in the repo — they are scratch tools for a single iteration.

## Why these specifics

- **`open [file normalize ./_ks-smoke.log]`** — `/tmp` does not behave the same way under `tclkit` as under bash on Windows; writing next to the project guarantees the path exists.
- **`exit 0` in `finally`** — without it, Tk's event loop blocks the process and your shell sits there forever waiting for the GUI window to close.
- **`update` before assertions** — Tk dispatches `<<ThemeChanged>>` and other virtual events asynchronously; without `update`, your assertions can run before refresh callbacks fire.
- **`source kitchen-sink.tcl`** — easier than reproducing widget setup inline. The kitchen sink already exercises one of every standard widget.
- **`-format $::tk::svgFmt`** is automatic when the kitchen sink is sourced; you don't need to set it again in the smoke wrapper.

## Useful introspection commands

| Command | Purpose |
| --- | --- |
| `ttk::style theme use` | Current theme name |
| `ttk::style theme names` | All registered themes |
| `ttk::style configure TFoo` | Inspect every option configured for a class |
| `ttk::style lookup TFoo -opt ?$state?` | Resolved value with optional state |
| `ttk::style map TFoo -opt` | State map for an option |
| `ttk::style layout TFoo` | Element layout (and child elements) for a class |
| `ttk::style element names` | All elements registered in the current theme |
| `ttk::style element options $elem` | Options accepted by an element |
| `image names` | All photo images currently registered |
| `image width $photo` / `image height $photo` | Photo dimensions in pixels |
| `bind $tag $event` | Bindings on a tag (widget, class, or `all`) |
| `bindtags $widget` | Order bindings propagate through |
| `winfo class .` | Class of a widget (used for application-class bindings) |
| `winfo ismapped .` | Whether a widget has been realized — required before some Win32 calls |
| `winfo children $w` | Tree shape under a widget |

## Common assertions we run

```tcl
# Theme is active
expr {[ttk::style theme use] eq "spectrum"}

# A class style is configured (returns the configure dict)
ttk::style configure TLabel

# An option resolves to a token value
expr {[ttk::style lookup TEntry -fieldbackground] eq $::spectrum::var(gray-50)}

# A state-mapped value is right
expr {[ttk::style lookup TEntry -bordercolor focus] eq $::spectrum::var(focus-indicator-color)}

# A custom image element is registered
expr {"Spectrum.Checkbutton.indicator" in [ttk::style element names]}

# A photo exists at expected dimensions (width depends on tk::scalingPct)
expr {"::spectrum::priv::cb_default" in [image names]}
```

## Dark-mode toggle in a smoke script

The vars file is sourced once at `package require` time and bakes the current `darkmode` into hex values. To verify dark/light differences without restarting:

```tcl
set ::spectrum::var(darkmode) [expr {!$::spectrum::var(darkmode)}]
source [file join [file dirname [info script]] spectrum-vars.tcl]
spectrum::theme use
update
```

This re-sources the vars (which re-evaluates the `[expr {$var(darkmode) ? ... : ...}]` lookups) and re-applies the theme. Image-element photos created via `::spectrum::priv::set_image` redraw in place because they are referenced by name, so the elements continue to work without rebuilding.

## When smoke isn't enough — visual verification

For anything that depends on rendered pixels (rounded corners aligning with `-border` zones, font weight, hit-target spacing), smoke output cannot tell you whether it looks right. Run `kitchen-sink.tcl` directly in `tclkit` (no wrapper) and look at it:

```sh
./tclkit-9.0.3-x86_64-w64-mingw32.exe kitchen-sink.tcl
```

The header bar has a dark-mode toggle so you can flip modes without restarting. The notebook tabs cover Buttons / Inputs / Indicators / Selection / Containers / Canvas — every standard Tk and Ttk widget appears at least once.

## Conventions

- **One smoke wrapper per chunk** — when investigating a specific feature, write one wrapper that asserts everything you care about and remove it after the chunk lands.
- **`_`-prefixed names** for any throwaway script or log so `git status` makes it obvious they're not part of the repo.
- **No smoke wrappers in commits** — clean them up before `git add`.
- **No `update` polling loops** — if you need to wait for something async, use `vwait` with a guard or restructure the test.
