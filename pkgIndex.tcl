
# Copyright (c) 2025, Bandoti Ltd.

if {![package vsatisfies [package provide Tcl] 8.6-]} {return}
package ifneeded spectrum 0.1.0 [list source [file join $dir spectrum.tcl]]
