#!/usr/bin/env tclsh

# Copyright (c) 2025, Bandoti Ltd.

package require tjson

# Helper script to generate Tcl initialization procedures for spectrum
# color palettes, layouts and fonts. This parses JSON design tokens and
# generates corresponding var array containing amalgamated variables.

set verbose [::apply {{} {
    set found [lsearch -exact $::argv "-verbose"]
    if {$found != -1} {
        set ::argv [lreplace $::argv $found $found]
        return 1
    }
    return 0
}}]

if {[llength $argv] != 1} {
    puts stderr "Usage: tclsh gen-spectrum-vars.tcl ?-verbose? <spectrum-tokens-dir>"
    exit 1
}

set spectrum_dir [lindex $argv 0]

if {! [file isdirectory $spectrum_dir]} {
    puts stderr "\"$spectrumdir\" must be a valid directory"
    exit 1
}

set NS ::spectrum ;# When loading at runtime

set var [list]

proc rgb_to_hex {rgb_string} {
    if {[regexp {^{(\S+)}$} $rgb_string -> varname]} {
        return "\$var($varname)" ;# An alias to another value
    }

    if {[regexp {rgb\s*\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*\)} $rgb_string -> r g b]} {
        return [format "\"#%02X%02X%02X\"" $r $g $b]

    } else {
        throw {RGBSTR INVALID} "Invalid RGB format: $rgb_string"
    }
}

proc parse_json_file {file} {
    try {
        set fd [open $file r]
        return [::tjson::json_to_simple [read $fd]]

    } finally {
        catch {close $fd}
    }
}

proc cmpkeys {a b} {
    if {![regexp {^(.+)-(\d+)$} $a -> a_prefix a_num]} {
        set a_prefix $a
        set a_num -1
    }
    if {![regexp {^(.+)-(\d+)$} $b -> b_prefix b_num]} {
        set b_prefix $b
        set b_num -1
    }
    set color_cmp [string compare $a_prefix $b_prefix]
    expr {$color_cmp != 0 ? $color_cmp : ($a_num < $b_num ? -1 : ($a_num > $b_num ? 1 : 0))}
}

proc parse_colors {color_dict} {
    foreach key [lsort -command cmpkeys [dict keys $color_dict]] {
        try {
            if {[dict exists $color_dict $key sets]} {
                set lightval [rgb_to_hex [dict get $color_dict $key sets light value]]
                set darkval  [rgb_to_hex [dict get $color_dict $key sets dark  value]]
                lappend ::var $key "\[expr {\$var(darkmode) ? $darkval : $lightval}\]"

            } else {
                lappend ::var $key [rgb_to_hex [dict get $color_dict $key value]]
            }

        } trap {RGBSTR INVALID} res {
            if {$::verbose} { puts stderr $res }
        }
    }
}

# Process values for layout & font JSON entries.
proc val_to_num {px_string} {
    if {[regexp {^{(\S+)}$} $px_string -> varname]} {
        # Handle variable references
        if {[string match "*font*" $varname]} {
            if {! [string match "*font-size*" $varname]} {
                # Only support font-size because Tk fonts work
                # differently than CSS fonts. Fonts will be created
                # and referenced directly.
                throw {PXVAL INVALID} "Invalid size format: $px_string"
            }
        }
        return "\$var($varname)"
    }
    if {[regexp {^(-?\d+)px$} $px_string -> px_value]} {
        return "\[scale_pixel $px_value\]"

    } elseif {[regexp {^(-?[\d.]+)$} $px_string -> value]} {
        return $value

    } else {
        throw {PXVAL INVALID} "Invalid size format: $px_string"
    }
}

proc parse_layout {layout_dict} {
    foreach key [lsort -command cmpkeys [dict keys $layout_dict]] {
        try {
            if {[dict exists $layout_dict $key sets]} {
                lappend ::var $key [val_to_num [dict get $layout_dict $key sets desktop value]]

            } else {
                lappend ::var $key [val_to_num [dict get $layout_dict $key value]]
            }

        } trap {PXVAL INVALID} res {
            if {$::verbose} { puts stderr $res }
        }
    }
}

proc parse_font {font_dict} {
    # The only font variables of use to Tk are the sizing-/spacing-
    # related values and font families. This routine expects that there will be
    # appropriate font names populated in var at runtime. For example,
    # set var(sans-serif-font-family) "Segoe UI"
    # This is required because Adobe's fonts are proprietary and so the
    # best available system font should be calculated.
    foreach key [lsort -command cmpkeys [dict keys $font_dict]] {
        if {[dict exists $font_dict $key value fontFamily]} {
            set family [dict get $font_dict $key value fontFamily]
            set size [dict get $font_dict $key value fontSize]
            set bold [string match "*bold*" [dict get $font_dict $key value fontWeight]]
            lappend ::var $key "\[${::NS}::priv::get_or_create_font $family $size $bold\]"
            continue
        }
        switch -glob -- $key {
            *size*    -
            *height*  -
            *margin*  -
            *color*   -
            *spacing* {
                try {
                    if {[dict exists $font_dict $key sets]} {
                        lappend ::var $key [val_to_num [dict get $font_dict $key sets desktop value]]

                    } else {
                        lappend ::var $key [val_to_num [dict get $font_dict $key value]]
                    }

                } trap {PXVAL INVALID} res {
                    if {$::verbose} { puts stderr $res }
                }
            }
        }
    }
}

oo::class create DependencySorter {
    variable Visited
    variable Sorted
    variable Elements

    method GetDependencies {value} {
        set deps    {}
        set pattern "\\\$var\\((\[^)]+)\\)"
        set matches [regexp -all -inline -- $pattern $value]
        if {$matches ne ""} {
            foreach {_ dep} $matches {
                if {$dep eq "darkmode"} { continue }
                lappend deps $dep
            }
        }
        return $deps
    }

    method Dfs {key value} {
        set Visited($key) 1
        set deps [my GetDependencies $value]
        foreach dep $deps {
            if {! [dict exists $Elements $dep] || $Visited($dep) eq "skipped"} {
                set Visited($key) "skipped"
                if {$::verbose} {
                    puts stderr "Skipping \"$key\" due to missing dependency \"$dep\""
                }
                return
            }
            if {$Visited($dep) eq "pending"} {
                my Dfs $dep [dict get $Elements $dep]

            }
        }
        lappend Sorted $key $value
    }

    constructor {elements} {
        set Elements $elements
    }

    method sort {} {
        array set Visited {}
        set Sorted [list]
        foreach {key _} $Elements { set Visited($key) "pending" }
        foreach {key value} $Elements {
            if {$Visited($key) eq "pending"} {
                my Dfs $key $value
            }
        }
        return $Sorted
    }
}

proc toposort {elements} {
    set sorter [DependencySorter new $elements]
    set result [$sorter sort]
    $sorter destroy
    return $result
}

set template {
# Copyright (c) 2025, Bandoti Ltd.

# This file is generated from Adobe Spectrum design tokens.
# Source: https://github.com/adobe/spectrum-tokens
# Copyright 2017 Adobe Systems Incorporated
# Licensed under Apache License 2.0
# Generated by @SCRIPT_NAME@ on @DATE@

namespace eval @NS@ {
@VARS@
}}

try {
    foreach color_file {
        color-palette.json
        semantic-color-palette.json
        color-aliases.json
        color-component.json
        icons.json
    } {
        set color_dict [parse_json_file [file join $spectrum_dir $color_file]]
        parse_colors $color_dict
    }

    foreach layout_file {
        layout.json
        layout-component.json
    } {
        set layout_dict [parse_json_file [file join $spectrum_dir $layout_file]]
        parse_layout $layout_dict
    }

    set font_dict [parse_json_file [file join $spectrum_dir typography.json]]
    parse_font $font_dict

    set ::var [toposort $::var]

    set variables [join [lmap key [dict keys $var] val [dict values $var] {
        expr {"set var($key) $val"}
    }] \n]

    set scriptname [file tail [info script]]
    set date [clock format [clock seconds] -format "%Y-%m-%d %H:%M:%S"]
    puts [string map [list @SCRIPT_NAME@ $scriptname @DATE@ $date @NS@ $::NS @VARS@ $variables] $template]

} on error res {
    puts stderr "$res"
    exit 1
}
