# spectrum-tk Test Strategy

> Status: living document. Updated as the test suite grows.

Tests are kept **simple** and exercise the public surface. The goal is to catch regressions in token generation, theme activation, ttk style assertions, and component behaviour without resorting to heavy mocking, screenshot diffing, or test-only abstractions.

## Framework

`tcltest` (ships with Tcl). No third-party dependencies.

```tcl
package require tcltest
namespace import ::tcltest::*
```

UI behaviour is driven through Tk's `event generate` rather than by reaching into widget internals. If a user can do it with the keyboard or mouse, the test should do it the same way.

## Layout

```
test/
├── all.tcl                # entry point — sources every *.test
├── tokens.test            # gen-spectrum-vars output checks
├── theme.test             # theme activation, dark mode toggle, <<ThemeChanged>>
├── ttk_styles.test        # per-class style assertions (color, font, padding)
├── components/
│   ├── Button.test
│   ├── Switch.test
│   └── ...                # one test file per concrete component
└── helpers.tcl            # shared setup (root window, headless flags)
```

A test file mirrors the source file it covers: `components/Button.tcl` ↔ `test/components/Button.test`.

## Categories

### 1. Token generation

Sanity-check the generated `spectrum-vars.tcl`: that key tokens exist, that dark-mode aliases resolve, that pixel values pass through `scale_pixel`.

```tcl
test tokens-1.1 {gray-100 is defined} -body {
    info exists ::spectrum::var(gray-100)
} -result 1
```

### 2. Theme activation

Activating `spectrum::theme use` succeeds, registers the theme, and emits `<<ThemeChanged>>`.

```tcl
test theme-1.1 {theme use activates spectrum} -body {
    spectrum::theme use
    ttk::style theme use
} -result spectrum
```

### 3. ttk style assertions

For each ttk class we re-skin, assert the colours/fonts match the active token values.

```tcl
test ttk-label-1.1 {TLabel uses body-color foreground} -setup {
    spectrum::theme use
} -body {
    ttk::style lookup TLabel -foreground
} -result $::spectrum::var(body-color)
```

### 4. Component behaviour (event generate)

The most important category. Drive components by simulated input and assert the resulting state.

```tcl
test button-1.1 {Button -command fires on click} -setup {
    spectrum::theme use
    set ::clicked 0
    spectrum::button .b -text Click -command {set ::clicked 1}
    pack .b
    update idletasks
} -body {
    event generate .b <Button-1> -warp 1
    event generate .b <ButtonRelease-1>
    update
    set ::clicked
} -cleanup {
    destroy .b
} -result 1

test switch-1.1 {Switch toggles via spacebar} -setup {
    spectrum::theme use
    spectrum::switch .s -variable ::v
    pack .s
    focus -force .s
    update idletasks
} -body {
    event generate .s <Key-space>
    update
    set ::v
} -cleanup {
    destroy .s
    unset -nocomplain ::v
} -result 1
```

Tooltips, popovers, and other transient `toplevel` components are tested by triggering the activating event (`<Enter>`, focus) and asserting the resulting toplevel exists with the expected geometry/contents.

### 5. Object lifecycle

The `::spectrum::Component` aliasing pattern requires careful testing — destroying via the Tk path or via the OO `destroy` method must clean up both sides.

```tcl
test lifecycle-1.1 {destroying widget destroys object} -setup {
    spectrum::button .b
} -body {
    destroy .b
    info commands .b
} -result {}
```

## Running tests

```sh
./tclkit-9.0.3-<platform> test/all.tcl
```

`all.tcl` sources every `*.test` file under `test/` and reports per-suite pass/fail counts. Individual files can be run on their own for fast iteration.

## Conventions

- **One assertion per test** when practical — keeps failure messages precise.
- **Always `-cleanup`** — every `pack`/`grid` and every widget creation has a matching `destroy` so tests don't leak state.
- **`update idletasks`** before reading geometry; **`update`** after generating events that trigger callbacks.
- **No sleeps**. Use `update` and `vwait` with a timeout if you must wait on something async.
- **Headless friendly** — avoid features that require a visible display where possible. On Linux CI a virtual X server (`xvfb-run`) is the expected runner.
