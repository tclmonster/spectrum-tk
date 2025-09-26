
# Copyright (c) 2025, Bandoti Ltd.

package require Tk 8.6-

package provide spectrum 0.1.0

namespace eval ::spectrum {
    variable var

    proc DarkModeSetting {} {
	variable PRIV
	set darkmode 0
	catch {
	    if {[tk windowingsystem] eq "win32"} {
		package require registry
		set keypath {HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize}
		set darkmode [expr {[registry get $keypath AppsUseLightTheme] == 0}]

	    } elseif {[tk windowingsystem] eq "aqua"} {
		set istyle [exec defaults read -g AppleInterfaceStyle]
		set darkmode [expr {$istyle eq "Dark"}]

	    } else {
		set colorscheme_query {qdbus org.freedesktop.portal.Desktop /org/freedesktop/portal/desktop
		    org.freedesktop.portal.Settings.Read "org.freedesktop.appearance" "color-scheme"
		}
		set darkmode [expr {1 == [exec {*}$colorscheme_query]}]
	    }
	}
	return $darkmode
    }

    if {![info exists var(darkmode)]} {
	set var(darkmode) [DarkModeSetting]
    }

    set var(sans-serif-font-family) [::apply {{} {
        set families [switch -- [tk windowingsystem] {
            win32   {expr {{"Segoe UI" "Tahoma" "MS Sans Serif" "Arial"}}}
            aqua    {expr {{"SF Pro Text" "Lucida Grande" "Geneva"}}}
            default {expr {{"Noto Sans" "DejaVu Sans" "Liberation Sans" "Ubuntu"}}}
        }]
        foreach fam [concat "Source Sans Pro" $families] {
            if {$fam in [font families]} {
                return $fam
            }
        }
        return "Helvetica"
    }}]

    set var(serif-font-family) [::apply {{} {
        set families [switch -- [tk windowingsystem] {
            win32   {expr {{"Cambria" "Georgia"}}}
            aqua    {expr {{"Palatino" "Times"}}}
            default {expr {{"Noto Serif" "DejaVu Serif" "Liberation Serif"}}}
        }]
        foreach fam [concat "Source Serif Pro" $families] {
            if {$fam in [font families]} {
                return $fam
            }
        }
        return "Times New Roman"
    }}]

    set var(code-font-family) [::apply {{} {
        set families [switch -- [tk windowingsystem] {
            win32   {expr {{"Cascadia Code" "Consolas" "Lucida Console" "Courier New"}}}
            aqua    {expr {{"SF Mono" "Menlo" "Monaco"}}}
            default {expr {{"Noto Sans Mono" "DejaVu Sans Mono" "Liberation Mono" "Ubuntu Mono"}}}
        }]
        foreach fam [concat "Source Code Pro" $families] {
            if {$fam in [font families]} {
                return $fam
            }
        }
        return "Courier"
    }}]
}

namespace eval ::spectrum::priv {}

proc ::spectrum::priv::get_or_create_font {family_key size bold} {
    namespace upvar ::spectrum var var
    set weight [expr {$bold ? "bold" : "normal"}]
    set tk_font_name "${family_key}-${size}-${weight}"
    if {$tk_font_name in [font names]} {
        return $tk_font_name
    }
    set family  $var($family_key)
    set size_px $var($size)
    return [font create $tk_font_name -family $family -size -${size_px} -weight $weight]
}

proc ::spectrum::scale_pixel {pixel} {
    return [expr {int([tk scaling] * $pixel * 72.0/96.0)}] ;# CSS pixel is 1/96.0 inch
}


source [file join [file dirname [info script]] spectrum-vars.tcl]


proc ::spectrum::SetWindowColor {window color} {
    variable PRIV
    if {[tk windowingsystem] ne "win32" || [catch {package require cffi}]} {
        return
    }

    cffi::alias load win32
    cffi::Wrapper create dwmapi [file join $::env(windir) system32 dwmapi.dll]
    cffi::Wrapper create user32 [file join $::env(windir) system32 user32.dll]

    cffi::alias define HRESULT {long nonnegative winerror}
    dwmapi stdcall DwmSetWindowAttribute HRESULT {
        hwnd pointer.HWND dwAttribute DWORD pvAttribute pointer cbAttribute DWORD
    }

    user32 stdcall GetParent pointer.HWND {
        hwnd pointer.HWND
    }

    proc ::spectrum::HexToBGR {color} {
	if {[scan $color "#%2x%2x%2x" r g b] != 3} {
	    return -code error "Invalid hex color format: $color"
	}
	return [expr {($b << 16) | ($g << 8) | $r}]
    }

    proc ::spectrum::SetWindowColor {window color} {
        set DWMWA_CAPTION_COLOR 35
        set hwndptr [cffi::pointer make [winfo id $window] HWND]
        cffi::pointer safe $hwndptr
        set parentptr [GetParent $hwndptr]

        set colorptr [cffi::arena pushframe DWORD]
        cffi::memory set $colorptr DWORD [HexToBGR $color]

        set size [cffi::type size DWORD]
        DwmSetWindowAttribute $parentptr $DWMWA_CAPTION_COLOR $colorptr $size

        cffi::arena popframe
        cffi::pointer dispose $hwndptr
        cffi::pointer dispose $parentptr
    }

    tailcall SetWindowColor $window $color
}

oo::class create ::spectrum::Theme {
    constructor {} {
        ttk::style theme create spectrum -parent clam
        set appname [winfo class .]
        bind $appname <<ThemeChanged>> +[list [self] refreshBindings]
        bind $appname <<ThemeChanged>> +[list [self] refreshStyles]
        bind $appname <<ThemeChanged>> +[list [self] refreshOptions]
    }

    method refreshBindings {} {
        if {[ttk::style theme use] ne "spectrum"} {
            return
        }
        if {[info commands ::spectrum::SetWindowColor] ne ""} {
            set cmd [list ::spectrum::SetWindowColor %W $::spectrum::var(gray-100)]
            bind [winfo class .] <Map> $cmd
            bind Toplevel <Map> $cmd

            {*}[string map {%W .} $cmd]
        }
    }

    method refreshStyles {} {
        namespace upvar ::spectrum var var
        if {[ttk::style theme use] ne "spectrum"} {
            return
        }

        set border_color [expr {$var(darkmode) ? $var(gray-400) : $var(gray-300)}]
        ttk::style theme settings spectrum {
            ttk::style configure "." \
                -background $var(gray-100) \
                -foreground $var(body-color) \
                -selectbackground $var(neutral-background-color-selected-default) \
                -selectforeground $var(white) \
                -font $var(component-m-regular) \
                -relief flat \
                -bordercolor $border_color \
                -troughcolor $var(gray-50) \
                -highlightcolor $var(neutral-background-color-key-focus)

            #ttk::style map . -foreground [list {active !disabled} $var(activeForeground) disabled $C(disabledForeground)]
            #ttk::style map . -background [list {active !disabled} $C(activeBackground) disabled $C(disabledBackground)]
        }

        my RefreshScrollbar
        my RefreshButton

        ttk::style configure TSeparator -background $var(gray-300)
    }

    method RefreshScrollbar {} {
        namespace upvar ::spectrum var var
        ttk::style theme settings spectrum {
            ttk::style layout Vertical.TScrollbar {
                Vertical.Scrollbar.trough -sticky ns -children {
                    Vertical.Scrollbar.thumb -sticky nswe
                }
            }
            ttk::style layout Horizontal.TScrollbar {
                Horizontal.Scrollbar.trough -sticky we -children {
                    Horizontal.Scrollbar.thumb -sticky nswe
                }
            }
            set arrowsize [font measure spectrumui "M"]
            set scrollbar_bg [expr {$var(darkmode) ? $var(gray-500) : $var(gray-400)}]
            set thumb_bg $scrollbar_bg
            ttk::style configure TScrollbar -arrowsize $arrowsize \
                -gripcount 0 -borderwidth 0 -lightcolor $thumb_bg -darkcolor $thumb_bg \
                -background $scrollbar_bg

            set scrollbar_active_bg [expr {$var(darkmode) ? $var(gray-600) : $var(gray-500)}]
            ttk::style map TScrollbar \
                -lightcolor [list disabled $var(gray-75) {active !disabled} $scrollbar_active_bg] \
                -darkcolor  [list disabled $var(gray-75) {active !disabled} $scrollbar_active_bg] \
                -background [list disabled $var(disabled-background-color) {active !disabled} $scrollbar_active_bg]
        }
    }

    method RefreshButton {} {
        namespace upvar ::spectrum var var
        ttk::style theme settings spectrum {
            ttk::style configure TButton -background $var(gray-300) -foreground $var(neutral-content-color-default)
            ttk::style map TButton -background [list {hover !disabled} $var(gray-400)]

            ttk::style configure Primary.TButton -background $var(neutral-background-color-default) -foreground $var(white)
            ttk::style map Primary.TButton -background [list {hover !disabled} $var(neutral-background-color-hover)]

            ttk::style configure Accent.TButton -background $var(accent-background-color-default) -foreground $var(white)
            ttk::style map Accent.TButton -background [list {hover !disabled} $var(accent-background-color-hover)]
        }
    }

    method refreshOptions {} {
        namespace upvar ::spectrum var var
        if {[ttk::style theme use] ne "spectrum"} {
            return
        }

        tk_setPalette \
            background $var(gray-100) \
            foreground $var(body-color) \
            activeBackground $var(informative-background-color-default) \
            activeForeground $var(white) \
            selectBackground $var(informative-background-color-default) \
            selectForeground $var(white) \
            highlightColor $var(accent-content-color-key-focus) \
            highlightBackground $var(gray-200) \
            disabledForeground $var(disabled-content-color) \
            insertBackground $var(body-color) \
            troughColor $var(background-pasteboard-color)

        option add *Text.background $var(background-base-color)

        option add *Menu.background $var(gray-200)
        option add *Menu.foreground $var(body-color)
        option add *Menu.activeBackground $var(static-blue-900)
        option add *Menu.activeForeground $var(white)
        option add *Menu.selectColor $var(body-color)
        option add *Menu.disabledForeground [expr {$var(darkmode) ? $var(gray-600) : $var(gray-500)}]

        option add *font $var(component-m-regular)

        set widgets [list .]
        while {$widgets ne ""} {
            set widgets [lassign $widgets current]
            switch [winfo class $current] {
                Menu - Text { my RefreshWidget $current }
            }
            lappend widgets {*}[lreverse [winfo children $current]]
        }
    }

    method RefreshWidget {widget} {
        set options {
            background borderWidth foreground
            relief
            activeBackground activeBorderWidth activeForeground
            activeRelief
            selectBackground selectBorderWidth selectForeground
            selectColor
            highlightBackground highlightColor highlightThickness
            insertBackground insertBorderWidth
            insertWidth
            disabledForeground font
        }
        foreach opt $options {
            set name [string tolower $opt]
            catch {$widget configure -$name [option get $widget $opt [winfo class $widget]]}
        }
    }

    method use {} {
        ttk::style theme use spectrum
    }
}

namespace eval ::spectrum {
    Theme create theme
}
