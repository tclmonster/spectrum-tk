#!/usr/bin/env wish

# Kitchen sink — renders one of every standard Tk and Ttk widget so the
# Spectrum theme can be inspected visually as styles land.

lappend auto_path [file dirname [file normalize [info script]]]
package require spectrum
spectrum::theme use

wm title . "spectrum-tk kitchen sink"
wm geometry . 1100x720
wm minsize . 800 540

# --- Top bar ---------------------------------------------------------------
ttk::frame .top -padding 12
pack .top -side top -fill x

ttk::label .top.title -text "spectrum-tk kitchen sink"
ttk::label .top.theme -text ""

proc ::refreshHeader {} {
    .top.theme configure -text [format "Theme: %s   Dark: %s" \
        [ttk::style theme use] $::spectrum::var(darkmode)]
}

proc ::toggleDarkMode {} {
    set ::spectrum::var(darkmode) [expr {!$::spectrum::var(darkmode)}]
    source [file join [file dirname [info script]] spectrum-vars.tcl]
    spectrum::theme use
    ::refreshHeader
}

ttk::button .top.dark -text "Toggle dark mode" -command ::toggleDarkMode
ttk::button .top.quit -text Quit -command {destroy .}

pack .top.title -side left
pack .top.quit  -side right -padx {6 0}
pack .top.dark  -side right
pack .top.theme -side right -padx 12
::refreshHeader

ttk::separator .sep -orient horizontal
pack .sep -fill x

# --- Notebook ---------------------------------------------------------------
ttk::notebook .nb
pack .nb -fill both -expand 1 -padx 12 -pady 12

# ===== Buttons tab =========================================================
ttk::frame .nb.b -padding 10
.nb add .nb.b -text Buttons

ttk::labelframe .nb.b.ttk -text "ttk::button" -padding 10
ttk::button .nb.b.ttk.def  -text "Default"
ttk::button .nb.b.ttk.pri  -text "Primary"  -style Primary.TButton
ttk::button .nb.b.ttk.acc  -text "Accent"   -style Accent.TButton
ttk::button .nb.b.ttk.dis  -text "Disabled" -state disabled
grid .nb.b.ttk.def .nb.b.ttk.pri .nb.b.ttk.acc .nb.b.ttk.dis -padx 6 -pady 6 -sticky w

ttk::labelframe .nb.b.classic -text "tk::button" -padding 10
button .nb.b.classic.def -text "Default"
button .nb.b.classic.dis -text "Disabled" -state disabled
grid .nb.b.classic.def .nb.b.classic.dis -padx 6 -pady 6 -sticky w

ttk::labelframe .nb.b.checks -text "Checks & radios" -padding 10
ttk::checkbutton .nb.b.checks.tc1 -text "ttk check"
ttk::checkbutton .nb.b.checks.tc2 -text "Disabled" -state disabled
checkbutton      .nb.b.checks.cc  -text "Classic check"
ttk::radiobutton .nb.b.checks.tr1 -text "ttk radio"        -variable ::demo_r -value a
ttk::radiobutton .nb.b.checks.tr2 -text "Disabled"         -state disabled -variable ::demo_r -value b
radiobutton      .nb.b.checks.cr  -text "Classic radio"    -variable ::demo_r -value c
grid .nb.b.checks.tc1 .nb.b.checks.tc2 .nb.b.checks.cc -padx 6 -pady 4 -sticky w
grid .nb.b.checks.tr1 .nb.b.checks.tr2 .nb.b.checks.cr -padx 6 -pady 4 -sticky w

ttk::labelframe .nb.b.menus -text "Menu buttons" -padding 10
menu .demo_menu -tearoff 0
.demo_menu add command -label "Option one"
.demo_menu add command -label "Option two"
.demo_menu add separator
.demo_menu add command -label "Option three"
ttk::menubutton .nb.b.menus.tmb -text "ttk menubutton"  -menu .demo_menu
menubutton      .nb.b.menus.cmb -text "Classic menubutton" -menu .demo_menu -relief raised -indicatoron 1
grid .nb.b.menus.tmb .nb.b.menus.cmb -padx 6 -pady 6 -sticky w

grid .nb.b.ttk     -row 0 -column 0 -padx 4 -pady 4 -sticky nsew
grid .nb.b.classic -row 0 -column 1 -padx 4 -pady 4 -sticky nsew
grid .nb.b.checks  -row 1 -column 0 -columnspan 2 -padx 4 -pady 4 -sticky nsew
grid .nb.b.menus   -row 2 -column 0 -columnspan 2 -padx 4 -pady 4 -sticky nsew
grid columnconfigure .nb.b 0 -weight 1
grid columnconfigure .nb.b 1 -weight 1

# ===== Inputs tab ==========================================================
ttk::frame .nb.i -padding 10
.nb add .nb.i -text Inputs

ttk::labelframe .nb.i.entries -text "Entry" -padding 10
ttk::label .nb.i.entries.l1 -text "ttk::entry"
ttk::entry .nb.i.entries.e1
.nb.i.entries.e1 insert end "Hello, Spectrum"
ttk::label .nb.i.entries.l2 -text "Disabled"
ttk::entry .nb.i.entries.e2 -state disabled
.nb.i.entries.e2 insert end "Read-only value"
ttk::label .nb.i.entries.l3 -text "tk::entry"
entry      .nb.i.entries.e3
.nb.i.entries.e3 insert end "Classic"
grid .nb.i.entries.l1 .nb.i.entries.e1 -padx 6 -pady 4 -sticky w
grid .nb.i.entries.l2 .nb.i.entries.e2 -padx 6 -pady 4 -sticky w
grid .nb.i.entries.l3 .nb.i.entries.e3 -padx 6 -pady 4 -sticky w

ttk::labelframe .nb.i.combos -text "Combobox / Spinbox" -padding 10
ttk::combobox .nb.i.combos.cb -values {Alpha Beta Gamma Delta Epsilon} -width 14
.nb.i.combos.cb set "Alpha"
ttk::spinbox  .nb.i.combos.tsb -from 0 -to 100 -increment 1 -width 6
.nb.i.combos.tsb set 12
spinbox       .nb.i.combos.csb -from 0 -to 100 -increment 1 -width 6
.nb.i.combos.csb set 12
grid .nb.i.combos.cb .nb.i.combos.tsb .nb.i.combos.csb -padx 6 -pady 6 -sticky w

ttk::labelframe .nb.i.text -text "Text & Message" -padding 10
text .nb.i.text.t -height 5 -width 40 -wrap word
.nb.i.text.t insert end "tk::text supports tags, marks, embedded\nimages, and full styling. This block sits\non a styled background."
message .nb.i.text.m -text "tk::message — read-only line-wrapped paragraph widget that auto-fits to its width." -width 280
grid .nb.i.text.t .nb.i.text.m -padx 6 -pady 6 -sticky nsew

grid .nb.i.entries -row 0 -column 0 -padx 4 -pady 4 -sticky nsew
grid .nb.i.combos  -row 1 -column 0 -padx 4 -pady 4 -sticky nsew
grid .nb.i.text    -row 2 -column 0 -padx 4 -pady 4 -sticky nsew
grid columnconfigure .nb.i 0 -weight 1

# ===== Indicators tab ======================================================
ttk::frame .nb.ind -padding 10
.nb add .nb.ind -text Indicators

ttk::labelframe .nb.ind.prog -text "Progressbar" -padding 10
ttk::progressbar .nb.ind.prog.det   -mode determinate   -length 280 -value 60
ttk::progressbar .nb.ind.prog.indet -mode indeterminate -length 280
.nb.ind.prog.indet start
ttk::label .nb.ind.prog.ldet   -text "Determinate"
ttk::label .nb.ind.prog.lindet -text "Indeterminate"
grid .nb.ind.prog.ldet   .nb.ind.prog.det   -padx 6 -pady 6 -sticky w
grid .nb.ind.prog.lindet .nb.ind.prog.indet -padx 6 -pady 6 -sticky w

ttk::labelframe .nb.ind.scales -text "Scale" -padding 10
ttk::scale .nb.ind.scales.s -from 0 -to 100 -length 280
.nb.ind.scales.s set 35
ttk::scale .nb.ind.scales.sd -from 0 -to 100 -length 280 -state disabled
.nb.ind.scales.sd set 60
scale .nb.ind.scales.cs -from 0 -to 100 -length 280 -orient horizontal -showvalue 1
.nb.ind.scales.cs set 60
ttk::label .nb.ind.scales.lt -text "ttk::scale"
ttk::label .nb.ind.scales.ld -text "ttk::scale (disabled)"
ttk::label .nb.ind.scales.lc -text "tk::scale"
grid .nb.ind.scales.lt .nb.ind.scales.s  -padx 6 -pady 6 -sticky w
grid .nb.ind.scales.ld .nb.ind.scales.sd -padx 6 -pady 6 -sticky w
grid .nb.ind.scales.lc .nb.ind.scales.cs -padx 6 -pady 6 -sticky w

grid .nb.ind.prog   -row 0 -column 0 -padx 4 -pady 4 -sticky nsew
grid .nb.ind.scales -row 1 -column 0 -padx 4 -pady 4 -sticky nsew
grid columnconfigure .nb.ind 0 -weight 1

# ===== Selection tab =======================================================
ttk::frame .nb.s -padding 10
.nb add .nb.s -text Selection

ttk::labelframe .nb.s.list -text "Listbox" -padding 10
listbox .nb.s.list.l -height 8 -yscrollcommand {.nb.s.list.sb set}
foreach item {Apple Banana Cherry Date Elderberry Fig Grape Kiwi Lemon Mango Nectarine Orange} {
    .nb.s.list.l insert end $item
}
.nb.s.list.l selection set 1
ttk::scrollbar .nb.s.list.sb -orient vertical -command {.nb.s.list.l yview}
grid .nb.s.list.l .nb.s.list.sb -sticky nsew
grid columnconfigure .nb.s.list 0 -weight 1
grid rowconfigure    .nb.s.list 0 -weight 1

ttk::labelframe .nb.s.tree -text "Treeview" -padding 10
ttk::treeview .nb.s.tree.t -columns {size modified} -yscrollcommand {.nb.s.tree.sb set}
.nb.s.tree.t heading #0       -text Name
.nb.s.tree.t heading size     -text Size
.nb.s.tree.t heading modified -text Modified
set root [.nb.s.tree.t insert {} end -text "src" -values {-- 2026-04-28} -open 1]
.nb.s.tree.t insert $root end -text "spectrum.tcl"        -values {12K 2026-04-28}
.nb.s.tree.t insert $root end -text "spectrum-vars.tcl"   -values {138K 2026-04-28}
.nb.s.tree.t insert $root end -text "kitchen-sink.tcl"    -values {6K 2026-04-28}
.nb.s.tree.t insert {} end -text "docs"  -values {-- 2026-04-28}
.nb.s.tree.t insert {} end -text "tcltk" -values {-- 2026-04-28}
ttk::scrollbar .nb.s.tree.sb -orient vertical -command {.nb.s.tree.t yview}
grid .nb.s.tree.t .nb.s.tree.sb -sticky nsew
grid columnconfigure .nb.s.tree 0 -weight 1
grid rowconfigure    .nb.s.tree 0 -weight 1

grid .nb.s.list -row 0 -column 0 -padx 4 -pady 4 -sticky nsew
grid .nb.s.tree -row 0 -column 1 -padx 4 -pady 4 -sticky nsew
grid columnconfigure .nb.s 0 -weight 1
grid columnconfigure .nb.s 1 -weight 2
grid rowconfigure    .nb.s 0 -weight 1

# ===== Containers tab ======================================================
ttk::frame .nb.c -padding 10
.nb add .nb.c -text Containers

ttk::labelframe .nb.c.frames -text "Frame & Labelframe" -padding 10
ttk::frame .nb.c.frames.tf -width 160 -height 80 -borderwidth 1 -relief solid
ttk::label .nb.c.frames.tf.l -text "ttk::frame"
pack       .nb.c.frames.tf.l -expand 1
pack propagate .nb.c.frames.tf 0
frame .nb.c.frames.cf -width 160 -height 80 -borderwidth 1 -relief solid
label .nb.c.frames.cf.l -text "tk::frame"
pack  .nb.c.frames.cf.l -expand 1
pack propagate .nb.c.frames.cf 0
labelframe .nb.c.frames.clf -text "tk::labelframe" -padx 8 -pady 8
label      .nb.c.frames.clf.l -text "Inside classic"
pack       .nb.c.frames.clf.l
grid .nb.c.frames.tf .nb.c.frames.cf .nb.c.frames.clf -padx 6 -pady 6 -sticky nsew

ttk::labelframe .nb.c.paned -text "Panedwindow" -padding 10
ttk::panedwindow .nb.c.paned.pw -orient horizontal
ttk::frame .nb.c.paned.pw.left  -padding 8
ttk::label .nb.c.paned.pw.left.l -text "Left pane"
pack       .nb.c.paned.pw.left.l -expand 1 -fill both
ttk::frame .nb.c.paned.pw.right -padding 8
ttk::label .nb.c.paned.pw.right.l -text "Right pane"
pack       .nb.c.paned.pw.right.l -expand 1 -fill both
.nb.c.paned.pw add .nb.c.paned.pw.left  -weight 1
.nb.c.paned.pw add .nb.c.paned.pw.right -weight 1
pack .nb.c.paned.pw -fill both -expand 1

ttk::labelframe .nb.c.misc -text "Separator & Sizegrip" -padding 10
ttk::separator .nb.c.misc.h -orient horizontal
ttk::sizegrip  .nb.c.misc.g
grid .nb.c.misc.h -sticky we -padx 6 -pady 8
grid .nb.c.misc.g -sticky e  -padx 6 -pady 6
grid columnconfigure .nb.c.misc 0 -weight 1

grid .nb.c.frames -row 0 -column 0 -padx 4 -pady 4 -sticky nsew
grid .nb.c.paned  -row 1 -column 0 -padx 4 -pady 4 -sticky nsew
grid .nb.c.misc   -row 2 -column 0 -padx 4 -pady 4 -sticky nsew
grid columnconfigure .nb.c 0 -weight 1
grid rowconfigure    .nb.c 1 -weight 1

# ===== Canvas tab ==========================================================
ttk::frame .nb.cv -padding 10
.nb add .nb.cv -text Canvas
canvas .nb.cv.c -width 800 -height 220 -highlightthickness 0
pack   .nb.cv.c -fill both -expand 1
.nb.cv.c create rectangle 30 30 220 130 \
    -fill $::spectrum::var(neutral-background-color-default) -outline ""
.nb.cv.c create text 125 80 \
    -text "tk::canvas" -fill $::spectrum::var(white) \
    -font [list $::spectrum::var(sans-serif-font-family) 16 bold]
.nb.cv.c create oval 260 30 380 150 \
    -fill $::spectrum::var(accent-background-color-default) -outline ""
.nb.cv.c create line 420 90 760 90 \
    -fill $::spectrum::var(body-color) -width 2 -arrow last
