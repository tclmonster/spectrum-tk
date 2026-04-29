
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

namespace eval ::spectrum::priv {
    variable svg_cache
    array set svg_cache {}
}

# Rasterize an SVG string to a Tk photo image, caching by content + DPI scaling.
# Repeated calls with identical $svg_data return the same image name.
proc ::spectrum::priv::svg_image {svg_data} {
    variable svg_cache
    set key [list $::tk::scalingPct $svg_data]
    if {[info exists svg_cache($key)]} {
        return $svg_cache($key)
    }
    set img [image create photo -format $::tk::svgFmt -data $svg_data]
    set svg_cache($key) $img
    return $img
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

            # Apply to the existing root toplevel only once it is mapped — the
            # dwmapi call needs a realized HWND.
            if {[winfo ismapped .]} {
                {*}[string map {%W .} $cmd]
            }
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
        my RefreshLabel
        my RefreshFrame
        my RefreshLabelframe
        my RefreshEntry
        my RefreshCombobox
        my RefreshSpinbox
        my RefreshMenubutton
        my RefreshNotebook
        my RefreshProgressbar
        my RefreshScale

        ttk::style configure TSeparator -background $var(gray-300)
    }

    method RefreshLabel {} {
        namespace upvar ::spectrum var var
        ttk::style theme settings spectrum {
            ttk::style configure TLabel \
                -background $var(gray-100) \
                -foreground $var(body-color) \
                -font $var(component-m-regular)
            ttk::style map TLabel \
                -foreground [list disabled $var(disabled-content-color)]
        }
    }

    method RefreshFrame {} {
        namespace upvar ::spectrum var var
        ttk::style theme settings spectrum {
            ttk::style configure TFrame -background $var(gray-100) -borderwidth 0
        }
    }

    method RefreshLabelframe {} {
        namespace upvar ::spectrum var var
        set border [expr {$var(darkmode) ? $var(gray-400) : $var(gray-300)}]
        ttk::style theme settings spectrum {
            ttk::style configure TLabelframe \
                -background $var(gray-100) \
                -bordercolor $border \
                -lightcolor $border \
                -darkcolor $border \
                -borderwidth 1 \
                -relief solid
            ttk::style configure TLabelframe.Label \
                -background $var(gray-100) \
                -foreground $var(body-color) \
                -font $var(component-m-regular)
        }
    }

    method RefreshEntry {} {
        namespace upvar ::spectrum var var
        set border       [expr {$var(darkmode) ? $var(gray-400) : $var(gray-400)}]
        set border_hover [expr {$var(darkmode) ? $var(gray-500) : $var(gray-500)}]
        set focus_color  $var(focus-indicator-color)
        ttk::style theme settings spectrum {
            ttk::style configure TEntry \
                -fieldbackground $var(gray-50) \
                -foreground $var(body-color) \
                -insertcolor $var(body-color) \
                -bordercolor $border \
                -lightcolor $border \
                -darkcolor $border \
                -borderwidth 1 \
                -padding [list $var(spacing-200) $var(spacing-100)] \
                -font $var(component-m-regular)
            ttk::style map TEntry \
                -fieldbackground [list disabled $var(disabled-background-color)] \
                -foreground      [list disabled $var(disabled-content-color)] \
                -bordercolor     [list \
                    disabled            $border \
                    {focus !disabled}   $focus_color \
                    {hover !disabled}   $border_hover] \
                -lightcolor      [list \
                    disabled            $border \
                    {focus !disabled}   $focus_color \
                    {hover !disabled}   $border_hover] \
                -darkcolor       [list \
                    disabled            $border \
                    {focus !disabled}   $focus_color \
                    {hover !disabled}   $border_hover]
        }
    }

    method RefreshCombobox {} {
        namespace upvar ::spectrum var var
        set border       [expr {$var(darkmode) ? $var(gray-400) : $var(gray-400)}]
        set border_hover [expr {$var(darkmode) ? $var(gray-500) : $var(gray-500)}]
        set focus_color  $var(focus-indicator-color)
        ttk::style theme settings spectrum {
            ttk::style configure TCombobox \
                -fieldbackground $var(gray-50) \
                -background $var(gray-50) \
                -foreground $var(body-color) \
                -arrowcolor $var(body-color) \
                -insertcolor $var(body-color) \
                -bordercolor $border \
                -lightcolor $border \
                -darkcolor $border \
                -borderwidth 1 \
                -padding [list $var(spacing-200) $var(spacing-100)] \
                -font $var(component-m-regular)
            ttk::style map TCombobox \
                -fieldbackground [list disabled $var(disabled-background-color)] \
                -foreground      [list disabled $var(disabled-content-color)] \
                -arrowcolor      [list disabled $var(disabled-content-color)] \
                -bordercolor     [list \
                    disabled            $border \
                    {focus !disabled}   $focus_color \
                    {hover !disabled}   $border_hover] \
                -lightcolor      [list \
                    disabled            $border \
                    {focus !disabled}   $focus_color \
                    {hover !disabled}   $border_hover] \
                -darkcolor       [list \
                    disabled            $border \
                    {focus !disabled}   $focus_color \
                    {hover !disabled}   $border_hover]
        }
        # The combobox popup is a tk::listbox configured via the option db.
        option add *TCombobox*Listbox.background       $var(gray-50)        widgetDefault
        option add *TCombobox*Listbox.foreground       $var(body-color)     widgetDefault
        option add *TCombobox*Listbox.selectBackground $var(neutral-background-color-selected-default) widgetDefault
        option add *TCombobox*Listbox.selectForeground $var(white)          widgetDefault
        option add *TCombobox*Listbox.borderWidth      0                    widgetDefault
        option add *TCombobox*Listbox.font             $var(component-m-regular) widgetDefault
    }

    method RefreshSpinbox {} {
        namespace upvar ::spectrum var var
        set border       [expr {$var(darkmode) ? $var(gray-400) : $var(gray-400)}]
        set border_hover [expr {$var(darkmode) ? $var(gray-500) : $var(gray-500)}]
        set focus_color  $var(focus-indicator-color)
        ttk::style theme settings spectrum {
            ttk::style configure TSpinbox \
                -fieldbackground $var(gray-50) \
                -background $var(gray-50) \
                -foreground $var(body-color) \
                -arrowcolor $var(body-color) \
                -insertcolor $var(body-color) \
                -bordercolor $border \
                -lightcolor $border \
                -darkcolor $border \
                -borderwidth 1 \
                -padding [list $var(spacing-200) $var(spacing-100)] \
                -font $var(component-m-regular)
            ttk::style map TSpinbox \
                -fieldbackground [list disabled $var(disabled-background-color)] \
                -foreground      [list disabled $var(disabled-content-color)] \
                -arrowcolor      [list disabled $var(disabled-content-color)] \
                -bordercolor     [list \
                    disabled            $border \
                    {focus !disabled}   $focus_color \
                    {hover !disabled}   $border_hover] \
                -lightcolor      [list \
                    disabled            $border \
                    {focus !disabled}   $focus_color \
                    {hover !disabled}   $border_hover] \
                -darkcolor       [list \
                    disabled            $border \
                    {focus !disabled}   $focus_color \
                    {hover !disabled}   $border_hover]
        }
    }

    method RefreshMenubutton {} {
        namespace upvar ::spectrum var var
        ttk::style theme settings spectrum {
            ttk::style configure TMenubutton \
                -background $var(gray-300) \
                -foreground $var(neutral-content-color-default) \
                -arrowcolor $var(body-color) \
                -bordercolor $var(gray-300) \
                -lightcolor  $var(gray-300) \
                -darkcolor   $var(gray-300) \
                -padding [list $var(spacing-200) $var(spacing-100)] \
                -relief flat \
                -font $var(component-m-regular)
            ttk::style map TMenubutton \
                -background [list \
                    disabled           $var(disabled-background-color) \
                    {hover !disabled}  $var(gray-400) \
                    {pressed !disabled} $var(gray-400)] \
                -foreground [list disabled $var(disabled-content-color)] \
                -arrowcolor [list disabled $var(disabled-content-color)]
        }
    }

    method RefreshNotebook {} {
        namespace upvar ::spectrum var var
        set tab_bg      $var(gray-100)
        set tab_active  [expr {$var(darkmode) ? $var(gray-200) : $var(gray-75)}]
        set tab_focus   $var(gray-50)
        ttk::style theme settings spectrum {
            ttk::style configure TNotebook \
                -background $var(gray-100) \
                -borderwidth 0 \
                -tabmargins [list 0 0 0 0]
            ttk::style configure TNotebook.Tab \
                -background $tab_bg \
                -foreground $var(body-color) \
                -bordercolor $var(gray-300) \
                -lightcolor  $var(gray-300) \
                -darkcolor   $var(gray-300) \
                -padding [list $var(spacing-300) $var(spacing-100)] \
                -font $var(component-m-regular)
            ttk::style map TNotebook.Tab \
                -background [list \
                    disabled            $var(disabled-background-color) \
                    selected            $tab_focus \
                    {hover !selected}   $tab_active] \
                -foreground [list \
                    disabled            $var(disabled-content-color) \
                    selected            $var(accent-content-color-default)]
        }
    }

    method RefreshProgressbar {} {
        namespace upvar ::spectrum var var
        ttk::style theme settings spectrum {
            ttk::style configure TProgressbar \
                -troughcolor $var(gray-300) \
                -background  $var(accent-background-color-default) \
                -bordercolor $var(gray-300) \
                -lightcolor  $var(accent-background-color-default) \
                -darkcolor   $var(accent-background-color-default) \
                -borderwidth 0 \
                -thickness   [::spectrum::scale_pixel 6]
            ttk::style map TProgressbar \
                -background [list disabled $var(disabled-content-color)] \
                -lightcolor [list disabled $var(disabled-content-color)] \
                -darkcolor  [list disabled $var(disabled-content-color)]
        }
    }

    method RefreshScale {} {
        namespace upvar ::spectrum var var
        set thumb        [expr {$var(darkmode) ? $var(gray-700) : $var(gray-800)}]
        set thumb_hover  [expr {$var(darkmode) ? $var(gray-800) : $var(gray-900)}]
        ttk::style theme settings spectrum {
            ttk::style configure TScale \
                -troughcolor $var(gray-300) \
                -background  $thumb \
                -bordercolor $thumb \
                -lightcolor  $thumb \
                -darkcolor   $thumb \
                -borderwidth 0
            ttk::style map TScale \
                -background [list \
                    disabled           $var(disabled-content-color) \
                    {active !disabled} $thumb_hover] \
                -lightcolor [list \
                    disabled           $var(disabled-content-color) \
                    {active !disabled} $thumb_hover] \
                -darkcolor  [list \
                    disabled           $var(disabled-content-color) \
                    {active !disabled} $thumb_hover]
        }
    }

    method RefreshScrollbar {} {
        namespace upvar ::spectrum var var

        # Native-feeling scrollbars: keep clam's default layout (which
        # includes uparrow/downarrow elements) and only adjust dimensions
        # and colors per platform.
        set base_em [font measure $var(component-m-regular) "M"]
        switch -- [tk windowingsystem] {
            aqua    { set arrowsize [expr {int($base_em * 0.85)}] }
            win32   { set arrowsize $base_em }
            default { set arrowsize $base_em }
        }

        set scrollbar_bg [expr {$var(darkmode) ? $var(gray-500) : $var(gray-400)}]
        set scrollbar_active_bg [expr {$var(darkmode) ? $var(gray-600) : $var(gray-500)}]

        ttk::style theme settings spectrum {
            ttk::style configure TScrollbar \
                -arrowsize $arrowsize \
                -gripcount 0 \
                -borderwidth 0 \
                -troughcolor $var(gray-200) \
                -background $scrollbar_bg \
                -lightcolor $scrollbar_bg \
                -darkcolor  $scrollbar_bg \
                -arrowcolor $var(body-color)
            ttk::style map TScrollbar \
                -background [list \
                    disabled            $var(disabled-background-color) \
                    {active !disabled}  $scrollbar_active_bg] \
                -lightcolor [list \
                    disabled            $var(gray-200) \
                    {active !disabled}  $scrollbar_active_bg] \
                -darkcolor  [list \
                    disabled            $var(gray-200) \
                    {active !disabled}  $scrollbar_active_bg] \
                -arrowcolor [list \
                    disabled            $var(disabled-content-color) \
                    {active !disabled}  $var(body-color)]
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
        # The <<ThemeChanged>> binding on [winfo class .] is not firing reliably;
        # invoke the refresh methods directly until that is investigated.
        my refreshBindings
        my refreshStyles
        my refreshOptions
    }
}

namespace eval ::spectrum {
    Theme create theme
}
