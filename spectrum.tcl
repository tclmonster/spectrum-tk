
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

# Create or refresh a stably-named photo image from an SVG string.
# Element images that need to update (e.g. on dark-mode toggle) reference
# photos by name; this lets the element auto-pick up the redrawn pixels.
proc ::spectrum::priv::set_image {name svg_data} {
    if {$name in [image names]} {
        $name configure -data $svg_data -format $::tk::svgFmt
    } else {
        image create photo $name -data $svg_data -format $::tk::svgFmt
    }
    return $name
}

# Generate an SVG string for a Spectrum-styled checkbox indicator in a
# particular ttk state (a list like {} {hover} {selected} {selected disabled}
# {alternate}).
proc ::spectrum::priv::checkbox_svg {state} {
    namespace upvar ::spectrum var var
    set selected   [expr {"selected"  in $state || "alternate" in $state}]
    set hover      [expr {"hover"     in $state}]
    set disabled   [expr {"disabled"  in $state}]
    set alternate  [expr {"alternate" in $state}]

    if {$disabled} {
        if {$selected} {
            set fill   $var(disabled-content-color)
            set border $var(disabled-content-color)
        } else {
            set fill   "none"
            set border $var(disabled-content-color)
        }
        set check $var(gray-50)
    } elseif {$selected} {
        if {$hover} {
            set fill   $var(accent-background-color-hover)
            set border $var(accent-background-color-hover)
        } else {
            set fill   $var(accent-background-color-default)
            set border $var(accent-background-color-default)
        }
        set check $var(white)
    } else {
        set fill "none"
        if {$hover} {
            set border [expr {$var(darkmode) ? $var(gray-400) : $var(gray-800)}]
        } else {
            set border [expr {$var(darkmode) ? $var(gray-500) : $var(gray-700)}]
        }
        set check $var(white)
    }

    if {$alternate} {
        set path "M3.5 7 L10.5 7"
    } else {
        set path "M3.5 7.5 L6 10 L10.5 4.5"
    }
    set check_opacity [expr {$selected ? 1 : 0}]

    set tpl {<svg xmlns="http://www.w3.org/2000/svg" width="14" height="14" viewBox="0 0 14 14">
<rect x="0.5" y="0.5" width="13" height="13" rx="3" fill="%FILL%" stroke="%BORDER%" stroke-width="1"/>
<path d="%PATH%" fill="none" stroke="%CHECK%" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" opacity="%OPAC%"/>
</svg>}
    return [string map [list \
        %FILL%   $fill   %BORDER% $border  %CHECK% $check \
        %PATH%   $path   %OPAC%   $check_opacity] $tpl]
}

# Generate an SVG string for the scrollbar trough (solid fill).
proc ::spectrum::priv::scrollbar_track_svg {} {
    namespace upvar ::spectrum var var
    set track [expr {$var(darkmode) ? $var(gray-300) : $var(gray-200)}]
    return [string map [list %BG% $track] {<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 16 16">
<rect width="16" height="16" fill="%BG%"/>
</svg>}]
}

# Generate an SVG string for a Win11-style scrollbar thumb. Designed for
# 9-slice stretching: the rounded caps sit entirely inside the -border
# zone, so the middle stretches as a solid color across long thumbs.
# $orient is "vertical" or "horizontal".
proc ::spectrum::priv::scrollbar_thumb_svg {orient state} {
    namespace upvar ::spectrum var var
    set hover    [expr {"active"   in $state}]
    set pressed  [expr {"pressed"  in $state}]
    set disabled [expr {"disabled" in $state}]

    if {$disabled} {
        set fill $var(disabled-content-color)
    } elseif {$pressed} {
        set fill [expr {$var(darkmode) ? $var(gray-800) : $var(gray-700)}]
    } elseif {$hover} {
        set fill [expr {$var(darkmode) ? $var(gray-700) : $var(gray-600)}]
    } else {
        set fill [expr {$var(darkmode) ? $var(gray-600) : $var(gray-500)}]
    }

    # Geometry: 16×16 image with a slim pill.
    #   Vertical:   pill at x=5, y=2, w=6, h=12, rx=3
    #               caps occupy y=2..5 and y=11..14; middle solid y=5..11
    #   Horizontal: rotated equivalent
    # With -border 5 (DPI-scaled at element-create time), the outer 5px on
    # the long axis hold the full rounded cap; the middle 6px is uniform
    # fill that stretches.
    if {$orient eq "vertical"} {
        set tpl {<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 16 16">
<rect x="5" y="2" width="6" height="12" rx="3" ry="3" fill="%FILL%"/>
</svg>}
    } else {
        set tpl {<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 16 16">
<rect x="2" y="5" width="12" height="6" rx="3" ry="3" fill="%FILL%"/>
</svg>}
    }
    return [string map [list %FILL% $fill] $tpl]
}

# Generate an SVG string for a Win11-style scrollbar chevron arrow button.
# $direction is up/down/left/right.
proc ::spectrum::priv::scrollbar_arrow_svg {direction state} {
    namespace upvar ::spectrum var var
    set hover    [expr {"active"   in $state}]
    set pressed  [expr {"pressed"  in $state}]
    set disabled [expr {"disabled" in $state}]

    if {$disabled} {
        set arrow $var(disabled-content-color)
        set bg [expr {$var(darkmode) ? $var(gray-300) : $var(gray-200)}]
    } else {
        set arrow $var(body-color)
        if {$pressed} {
            set bg [expr {$var(darkmode) ? $var(gray-500) : $var(gray-400)}]
        } elseif {$hover} {
            set bg [expr {$var(darkmode) ? $var(gray-400) : $var(gray-300)}]
        } else {
            set bg [expr {$var(darkmode) ? $var(gray-300) : $var(gray-200)}]
        }
    }

    switch -- $direction {
        up    { set path "M 4.5 9.5 L 8 6 L 11.5 9.5" }
        down  { set path "M 4.5 6.5 L 8 10 L 11.5 6.5" }
        left  { set path "M 9.5 4.5 L 6 8 L 9.5 11.5" }
        right { set path "M 6.5 4.5 L 10 8 L 6.5 11.5" }
    }

    return [string map [list %BG% $bg %ARROW% $arrow %PATH% $path] {<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 16 16">
<rect width="16" height="16" fill="%BG%"/>
<path d="%PATH%" stroke="%ARROW%" stroke-width="1.5" fill="none" stroke-linecap="round" stroke-linejoin="round"/>
</svg>}]
}

# Generate an SVG string for a Spectrum-styled radio indicator.
proc ::spectrum::priv::radio_svg {state} {
    namespace upvar ::spectrum var var
    set selected [expr {"selected" in $state}]
    set hover    [expr {"hover"    in $state}]
    set disabled [expr {"disabled" in $state}]

    if {$disabled} {
        set border $var(disabled-content-color)
        set dot    $var(disabled-content-color)
    } elseif {$selected} {
        if {$hover} {
            set border $var(accent-background-color-hover)
            set dot    $var(accent-background-color-hover)
        } else {
            set border $var(accent-background-color-default)
            set dot    $var(accent-background-color-default)
        }
    } else {
        if {$hover} {
            set border [expr {$var(darkmode) ? $var(gray-400) : $var(gray-800)}]
        } else {
            set border [expr {$var(darkmode) ? $var(gray-500) : $var(gray-700)}]
        }
        set dot $border
    }
    set dot_opacity [expr {$selected ? 1 : 0}]
    set border_w    [expr {$selected ? 1.5 : 1}]

    set tpl {<svg xmlns="http://www.w3.org/2000/svg" width="14" height="14" viewBox="0 0 14 14">
<circle cx="7" cy="7" r="6.25" fill="none" stroke="%BORDER%" stroke-width="%BW%"/>
<circle cx="7" cy="7" r="3" fill="%DOT%" opacity="%OPAC%"/>
</svg>}
    return [string map [list \
        %BORDER% $border %DOT% $dot %BW% $border_w %OPAC% $dot_opacity] $tpl]
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
            set cmd [list ::spectrum::SetWindowColor %W $::spectrum::var(background-base-color)]
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
        # See refreshOptions for the rationale: gray-800 selection background
        # is dark in light mode and light in dark mode, so the contrasting
        # content color must be the inverse — white on dark, gray-25 on light.
        set sel_fg [expr {$var(darkmode) ? $var(gray-25) : $var(white)}]
        ttk::style theme settings spectrum {
            ttk::style configure "." \
                -background $var(background-base-color) \
                -foreground $var(body-color) \
                -selectbackground $var(neutral-background-color-selected-default) \
                -selectforeground $sel_fg \
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
        my RefreshCheckbutton
        my RefreshRadiobutton
        my RefreshPanedwindow
        my RefreshSizegrip
        my RefreshTreeview

        ttk::style configure TSeparator -background $var(gray-300)
    }

    method RefreshLabel {} {
        namespace upvar ::spectrum var var
        ttk::style theme settings spectrum {
            ttk::style configure TLabel \
                -background $var(background-base-color) \
                -foreground $var(body-color) \
                -font $var(component-m-regular)
            ttk::style map TLabel \
                -foreground [list disabled $var(disabled-content-color)]
        }
    }

    method RefreshFrame {} {
        namespace upvar ::spectrum var var
        ttk::style theme settings spectrum {
            ttk::style configure TFrame -background $var(background-base-color) -borderwidth 0
        }
    }

    method RefreshLabelframe {} {
        namespace upvar ::spectrum var var
        set border [expr {$var(darkmode) ? $var(gray-400) : $var(gray-300)}]
        ttk::style theme settings spectrum {
            ttk::style configure TLabelframe \
                -background $var(background-base-color) \
                -bordercolor $border \
                -lightcolor $border \
                -darkcolor $border \
                -borderwidth 1 \
                -relief solid
            ttk::style configure TLabelframe.Label \
                -background $var(background-base-color) \
                -foreground $var(body-color) \
                -font $var(component-m-regular)
        }
    }

    method RefreshEntry {} {
        namespace upvar ::spectrum var var
        # Spectrum 2 textfield (per spectrum-css/components/textfield/themes/
        # spectrum-two.css): background = gray-25 (= page base), border
        # gray-500 default → gray-600 hover → focus indicator on focus →
        # gray-300 when disabled.
        set border       $var(gray-500)
        set border_hover $var(gray-600)
        set focus_color  $var(focus-indicator-color)
        ttk::style theme settings spectrum {
            ttk::style configure TEntry \
                -fieldbackground $var(background-base-color) \
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
                    disabled            $var(disabled-border-color) \
                    {focus !disabled}   $focus_color \
                    {hover !disabled}   $border_hover] \
                -lightcolor      [list \
                    disabled            $var(disabled-border-color) \
                    {focus !disabled}   $focus_color \
                    {hover !disabled}   $border_hover] \
                -darkcolor       [list \
                    disabled            $var(disabled-border-color) \
                    {focus !disabled}   $focus_color \
                    {hover !disabled}   $border_hover]
        }
    }

    method RefreshCombobox {} {
        namespace upvar ::spectrum var var
        # Spectrum 2 picker (per spectrum-css/components/picker/themes/
        # spectrum-two.css): background = gray-100 (button-like surface, not
        # the field surface — clicking opens a popover), border gray-500
        # default → gray-600 hover, gray-300 when disabled.
        set border       $var(gray-500)
        set border_hover $var(gray-600)
        set focus_color  $var(focus-indicator-color)
        ttk::style theme settings spectrum {
            ttk::style configure TCombobox \
                -fieldbackground $var(gray-100) \
                -background $var(gray-100) \
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
                    disabled            $var(disabled-border-color) \
                    {focus !disabled}   $focus_color \
                    {hover !disabled}   $border_hover] \
                -lightcolor      [list \
                    disabled            $var(disabled-border-color) \
                    {focus !disabled}   $focus_color \
                    {hover !disabled}   $border_hover] \
                -darkcolor       [list \
                    disabled            $var(disabled-border-color) \
                    {focus !disabled}   $focus_color \
                    {hover !disabled}   $border_hover]
        }
        # Combobox popup listbox option-db entries are installed in
        # refreshOptions (see "Combobox popup listbox" block).
    }

    method RefreshSpinbox {} {
        namespace upvar ::spectrum var var
        # Spinbox is treated as a textfield with stepper buttons — bg matches
        # TEntry per Spectrum 2 conventions.
        set border       $var(gray-500)
        set border_hover $var(gray-600)
        set focus_color  $var(focus-indicator-color)
        ttk::style theme settings spectrum {
            ttk::style configure TSpinbox \
                -fieldbackground $var(background-base-color) \
                -background $var(background-base-color) \
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
                    disabled            $var(disabled-border-color) \
                    {focus !disabled}   $focus_color \
                    {hover !disabled}   $border_hover] \
                -lightcolor      [list \
                    disabled            $var(disabled-border-color) \
                    {focus !disabled}   $focus_color \
                    {hover !disabled}   $border_hover] \
                -darkcolor       [list \
                    disabled            $var(disabled-border-color) \
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
        # Selected tab merges with the panel below (background-base-color).
        # Default and hover tabs sit one or two layer-steps below the panel so
        # unselected tabs read as inactive.
        set tab_bg      $var(gray-100)
        set tab_hover   [expr {$var(darkmode) ? $var(gray-200) : $var(gray-75)}]
        set tab_sel     $var(background-base-color)
        ttk::style theme settings spectrum {
            ttk::style configure TNotebook \
                -background $var(background-base-color) \
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
                    selected            $tab_sel \
                    {hover !selected}   $tab_hover] \
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

    method RefreshCheckbutton {} {
        namespace upvar ::spectrum var var

        # Build / refresh the per-state photos. Stable names mean the element
        # picks up redraws (e.g. on dark-mode toggle) automatically.
        set states {
            default {}
            hov     {hover}
            dis     {disabled}
            sel     {selected}
            selhov  {selected hover}
            seldis  {selected disabled}
            alt     {alternate}
            althov  {alternate hover}
            altdis  {alternate disabled}
        }
        foreach {key state} $states {
            ::spectrum::priv::set_image ::spectrum::priv::cb_$key \
                [::spectrum::priv::checkbox_svg $state]
        }

        ttk::style theme settings spectrum {
            if {"Spectrum.Checkbutton.indicator" ni [ttk::style element names]} {
                ttk::style element create Spectrum.Checkbutton.indicator image [list \
                    ::spectrum::priv::cb_default \
                    {alternate disabled} ::spectrum::priv::cb_altdis \
                    {alternate hover}    ::spectrum::priv::cb_althov \
                    alternate            ::spectrum::priv::cb_alt \
                    {selected disabled}  ::spectrum::priv::cb_seldis \
                    {selected hover}     ::spectrum::priv::cb_selhov \
                    selected             ::spectrum::priv::cb_sel \
                    disabled             ::spectrum::priv::cb_dis \
                    hover                ::spectrum::priv::cb_hov] \
                    -sticky w -padding [list 0 0 6 0]
            }
            ttk::style layout TCheckbutton {
                Checkbutton.padding -sticky nswe -children {
                    Spectrum.Checkbutton.indicator -side left -sticky {}
                    Checkbutton.focus -side left -sticky w -children {
                        Checkbutton.label -sticky nswe
                    }
                }
            }
            ttk::style configure TCheckbutton \
                -background $var(background-base-color) \
                -foreground $var(body-color) \
                -font $var(component-m-regular) \
                -padding [list 0 $var(spacing-100)]
            ttk::style map TCheckbutton \
                -background [list disabled $var(background-base-color)] \
                -foreground [list disabled $var(disabled-content-color)]
        }
    }

    method RefreshRadiobutton {} {
        namespace upvar ::spectrum var var

        set states {
            default {}
            hov     {hover}
            dis     {disabled}
            sel     {selected}
            selhov  {selected hover}
            seldis  {selected disabled}
        }
        foreach {key state} $states {
            ::spectrum::priv::set_image ::spectrum::priv::rb_$key \
                [::spectrum::priv::radio_svg $state]
        }

        ttk::style theme settings spectrum {
            if {"Spectrum.Radiobutton.indicator" ni [ttk::style element names]} {
                ttk::style element create Spectrum.Radiobutton.indicator image [list \
                    ::spectrum::priv::rb_default \
                    {selected disabled}  ::spectrum::priv::rb_seldis \
                    {selected hover}     ::spectrum::priv::rb_selhov \
                    selected             ::spectrum::priv::rb_sel \
                    disabled             ::spectrum::priv::rb_dis \
                    hover                ::spectrum::priv::rb_hov] \
                    -sticky w -padding [list 0 0 6 0]
            }
            ttk::style layout TRadiobutton {
                Radiobutton.padding -sticky nswe -children {
                    Spectrum.Radiobutton.indicator -side left -sticky {}
                    Radiobutton.focus -side left -sticky w -children {
                        Radiobutton.label -sticky nswe
                    }
                }
            }
            ttk::style configure TRadiobutton \
                -background $var(background-base-color) \
                -foreground $var(body-color) \
                -font $var(component-m-regular) \
                -padding [list 0 $var(spacing-100)]
            ttk::style map TRadiobutton \
                -background [list disabled $var(background-base-color)] \
                -foreground [list disabled $var(disabled-content-color)]
        }
    }

    method RefreshPanedwindow {} {
        namespace upvar ::spectrum var var
        set sash [expr {$var(darkmode) ? $var(gray-400) : $var(gray-300)}]
        ttk::style theme settings spectrum {
            ttk::style configure TPanedwindow -background $var(background-base-color)
            ttk::style configure Sash \
                -background    $sash \
                -bordercolor   $sash \
                -lightcolor    $sash \
                -darkcolor     $sash \
                -sashthickness [::spectrum::scale_pixel 4] \
                -gripcount     0
        }
    }

    method RefreshSizegrip {} {
        namespace upvar ::spectrum var var
        ttk::style theme settings spectrum {
            ttk::style configure TSizegrip \
                -background $var(background-base-color)
        }
    }

    method RefreshTreeview {} {
        namespace upvar ::spectrum var var
        set border       [expr {$var(darkmode) ? $var(gray-400) : $var(gray-300)}]
        set heading_bg   [expr {$var(darkmode) ? $var(gray-200) : $var(gray-75)}]
        set heading_hov  [expr {$var(darkmode) ? $var(gray-300) : $var(gray-100)}]
        set heading_pres [expr {$var(darkmode) ? $var(gray-400) : $var(gray-200)}]
        set hover_bg     $var(tree-view-row-background-hover)
        set sel_bg       $var(neutral-background-color-selected-default)
        set sel_fg       [expr {$var(darkmode) ? $var(gray-25) : $var(white)}]

        ttk::style theme settings spectrum {
            ttk::style configure Treeview \
                -background      $var(gray-50) \
                -foreground      $var(body-color) \
                -fieldbackground $var(gray-50) \
                -bordercolor     $border \
                -lightcolor      $border \
                -darkcolor       $border \
                -borderwidth     1 \
                -font            $var(component-m-regular) \
                -rowheight       [::spectrum::scale_pixel 20]
            ttk::style map Treeview \
                -background [list \
                    disabled            $var(disabled-background-color) \
                    selected            $sel_bg \
                    {hover !selected}   $hover_bg] \
                -foreground [list \
                    disabled $var(disabled-content-color) \
                    selected $sel_fg]

            ttk::style configure Treeview.Heading \
                -background  $heading_bg \
                -foreground  $var(body-color) \
                -bordercolor $border \
                -lightcolor  $border \
                -darkcolor   $border \
                -borderwidth 1 \
                -relief      flat \
                -padding     [list $var(spacing-200) $var(spacing-100)] \
                -font        $var(component-m-regular)
            ttk::style map Treeview.Heading \
                -background [list \
                    disabled            $var(disabled-background-color) \
                    {pressed !disabled} $heading_pres \
                    {hover !disabled}   $heading_hov] \
                -foreground [list disabled $var(disabled-content-color)]
        }
    }

    method RefreshScrollbar {} {
        namespace upvar ::spectrum var var

        # Build / refresh the per-element, per-state photos. Win11-style
        # scrollbar is unified across platforms.
        ::spectrum::priv::set_image ::spectrum::priv::sb_track \
            [::spectrum::priv::scrollbar_track_svg]

        foreach orient {vertical horizontal} {
            set short [string index $orient 0]
            foreach {key state} {default {} hov {active} prs {pressed} dis {disabled}} {
                ::spectrum::priv::set_image ::spectrum::priv::sb_thumb_${short}_${key} \
                    [::spectrum::priv::scrollbar_thumb_svg $orient $state]
            }
        }

        foreach direction {up down left right} {
            foreach {key state} {default {} hov {active} prs {pressed} dis {disabled}} {
                ::spectrum::priv::set_image ::spectrum::priv::sb_${direction}_${key} \
                    [::spectrum::priv::scrollbar_arrow_svg $direction $state]
            }
        }

        ttk::style theme settings spectrum {
            if {"Spectrum.Vscroll.trough" ni [ttk::style element names]} {
                ttk::style element create Spectrum.Vscroll.trough image \
                    ::spectrum::priv::sb_track -sticky ns
                ttk::style element create Spectrum.Hscroll.trough image \
                    ::spectrum::priv::sb_track -sticky we

                # -border is in photo pixels, so scale with DPI to match the
                # SVG's 9-slice geometry (5px in a 16×16 source image).
                set b5 [expr {int(round(5 * $::tk::scalingPct / 100.0))}]
                ttk::style element create Spectrum.Vscroll.thumb image \
                    [list ::spectrum::priv::sb_thumb_v_default \
                        disabled ::spectrum::priv::sb_thumb_v_dis \
                        pressed  ::spectrum::priv::sb_thumb_v_prs \
                        active   ::spectrum::priv::sb_thumb_v_hov] \
                    -sticky nswe -border [list $b5 $b5]
                ttk::style element create Spectrum.Hscroll.thumb image \
                    [list ::spectrum::priv::sb_thumb_h_default \
                        disabled ::spectrum::priv::sb_thumb_h_dis \
                        pressed  ::spectrum::priv::sb_thumb_h_prs \
                        active   ::spectrum::priv::sb_thumb_h_hov] \
                    -sticky nswe -border [list $b5 $b5]

                foreach {dir elem} {
                    up    Spectrum.Vscroll.uparrow
                    down  Spectrum.Vscroll.downarrow
                    left  Spectrum.Hscroll.leftarrow
                    right Spectrum.Hscroll.rightarrow
                } {
                    ttk::style element create $elem image \
                        [list ::spectrum::priv::sb_${dir}_default \
                            disabled ::spectrum::priv::sb_${dir}_dis \
                            pressed  ::spectrum::priv::sb_${dir}_prs \
                            active   ::spectrum::priv::sb_${dir}_hov] \
                        -sticky {}
                }
            }

            ttk::style layout Vertical.TScrollbar {
                Spectrum.Vscroll.trough -sticky ns -children {
                    Spectrum.Vscroll.uparrow   -side top    -sticky {}
                    Spectrum.Vscroll.downarrow -side bottom -sticky {}
                    Spectrum.Vscroll.thumb     -sticky nswe
                }
            }
            ttk::style layout Horizontal.TScrollbar {
                Spectrum.Hscroll.trough -sticky we -children {
                    Spectrum.Hscroll.leftarrow  -side left  -sticky {}
                    Spectrum.Hscroll.rightarrow -side right -sticky {}
                    Spectrum.Hscroll.thumb      -sticky nswe
                }
            }
        }
    }

    method RefreshButton {} {
        namespace upvar ::spectrum var var
        ttk::style theme settings spectrum {
            ttk::style configure TButton -background $var(gray-300) -foreground $var(neutral-content-color-default)
            ttk::style map TButton -background [list {hover !disabled} $var(gray-400)]

            # neutral-background-color-default is gray-800 in both modes —
            # dark in light mode, light in dark mode. The label needs the
            # inverse for contrast.
            set primary_fg [expr {$var(darkmode) ? $var(gray-25) : $var(white)}]
            ttk::style configure Primary.TButton -background $var(neutral-background-color-default) -foreground $primary_fg
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

        # We do not call tk_setPalette here. tk_setPalette installs broad
        # 1-component patterns like *background and *selectColor that
        # empirically beat our 2-component *Class.option patterns in the
        # option-db lookup, which is the opposite of what we want. It also
        # walks the widget tree and directly reconfigures every widget,
        # which would clobber later option add calls.
        #
        # Instead, we install everything explicitly: a small set of global
        # defaults at widgetDefault priority, then per-class overrides for
        # every classic widget the theme styles.
        # Selection: gray-800 background per Spectrum 2 states.md ("Selected
        # states use a primary style by default, generally through a gray-800
        # fill"). gray-800 is dark in light mode and light in dark mode, so
        # the selected-content color must be the inverse to keep contrast.
        # Spectrum has no neutral-content-color-selected token, so we derive
        # it: white on dark gray (light mode), gray-25 on light gray (dark).
        set sel_bg     $var(neutral-background-color-selected-default)
        set sel_fg     [expr {$var(darkmode) ? $var(gray-25) : $var(white)}]
        set hover_bg   [expr {$var(darkmode) ? $var(gray-300) : $var(gray-200)}]
        set fld_bg     $var(gray-50)
        set field_font $var(component-m-regular)
        set comp_font  $var(component-m-regular)

        # Global defaults for classic widgets. These match anything that
        # doesn't have a more-specific *Class.option entry below.
        option add *background          $var(background-base-color)   widgetDefault
        option add *foreground          $var(body-color)              widgetDefault
        option add *activeBackground    $hover_bg                     widgetDefault
        option add *activeForeground    $var(body-color)              widgetDefault
        option add *selectBackground    $sel_bg                       widgetDefault
        option add *selectForeground    $sel_fg                       widgetDefault
        option add *highlightColor      $var(focus-indicator-color)   widgetDefault
        option add *highlightBackground $var(background-base-color)   widgetDefault
        option add *disabledForeground  $var(disabled-content-color)  widgetDefault
        option add *insertBackground    $var(body-color)              widgetDefault
        option add *troughColor         $var(gray-300)                widgetDefault

        # Toplevel + Frame: canvas surface.
        option add *Toplevel.background    $var(background-base-color) widgetDefault
        option add *Frame.background       $var(background-base-color) widgetDefault

        # Label / Message: body text on canvas.
        option add *Label.background       $var(background-base-color) widgetDefault
        option add *Label.foreground       $var(body-color)            widgetDefault
        option add *Label.font             $comp_font                  widgetDefault
        option add *Message.background     $var(background-base-color) widgetDefault
        option add *Message.foreground     $var(body-color)            widgetDefault
        option add *Message.font           $comp_font                  widgetDefault

        # Button: matches default TButton (gray fill, neutral content).
        option add *Button.background          $var(gray-300)                       widgetDefault
        option add *Button.foreground          $var(neutral-content-color-default)  widgetDefault
        option add *Button.activeBackground    $var(gray-400)                       widgetDefault
        option add *Button.activeForeground    $var(neutral-content-color-default)  widgetDefault
        option add *Button.disabledForeground  $var(disabled-content-color)         widgetDefault
        option add *Button.borderWidth         0                                    widgetDefault
        option add *Button.relief              flat                                 widgetDefault
        option add *Button.highlightThickness  0                                    widgetDefault
        option add *Button.padX                $var(spacing-200)                    widgetDefault
        option add *Button.padY                $var(spacing-100)                    widgetDefault
        option add *Button.font                $comp_font                           widgetDefault

        # Checkbutton / Radiobutton (classic): canvas surface, accent-filled
        # indicator (selectColor) to mirror the Spectrum SVG indicators on
        # the ttk equivalents.
        foreach class {Checkbutton Radiobutton} {
            option add *${class}.background         $var(background-base-color)            widgetDefault
            option add *${class}.foreground         $var(body-color)                       widgetDefault
            option add *${class}.activeBackground   $var(background-base-color)            widgetDefault
            option add *${class}.activeForeground   $var(body-color)                       widgetDefault
            option add *${class}.selectColor        $var(accent-background-color-default)  widgetDefault
            option add *${class}.disabledForeground $var(disabled-content-color)           widgetDefault
            option add *${class}.borderWidth        0                                      widgetDefault
            option add *${class}.relief             flat                                   widgetDefault
            option add *${class}.highlightThickness 0                                      widgetDefault
            option add *${class}.font               $comp_font                             widgetDefault
        }

        # Entry / Spinbox (classic): in-set field (gray-50) with a 1px border.
        foreach class {Entry Spinbox} {
            option add *${class}.background         $fld_bg                       widgetDefault
            option add *${class}.foreground         $var(body-color)              widgetDefault
            option add *${class}.disabledBackground $var(disabled-background-color) widgetDefault
            option add *${class}.disabledForeground $var(disabled-content-color)  widgetDefault
            option add *${class}.insertBackground   $var(body-color)              widgetDefault
            option add *${class}.selectBackground   $sel_bg                       widgetDefault
            option add *${class}.selectForeground   $sel_fg                       widgetDefault
            option add *${class}.relief             solid                         widgetDefault
            option add *${class}.borderWidth        1                             widgetDefault
            option add *${class}.highlightThickness 0                             widgetDefault
            option add *${class}.font               $field_font                   widgetDefault
        }
        # Spinbox-specific: arrow buttons.
        option add *Spinbox.buttonBackground   $var(gray-300)                widgetDefault

        # Listbox: same field surface as Entry; popup-style border.
        option add *Listbox.background         $fld_bg                       widgetDefault
        option add *Listbox.foreground         $var(body-color)              widgetDefault
        option add *Listbox.selectBackground   $sel_bg                       widgetDefault
        option add *Listbox.selectForeground   $sel_fg                       widgetDefault
        option add *Listbox.disabledForeground $var(disabled-content-color)  widgetDefault
        option add *Listbox.relief             solid                         widgetDefault
        option add *Listbox.borderWidth        1                             widgetDefault
        option add *Listbox.highlightThickness 0                             widgetDefault
        option add *Listbox.font               $field_font                   widgetDefault

        # Scale (classic): trough + thumb mirror TScale.
        option add *Scale.troughColor         $var(gray-300)                                                widgetDefault
        option add *Scale.background          [expr {$var(darkmode) ? $var(gray-700) : $var(gray-800)}]    widgetDefault
        option add *Scale.activeBackground    [expr {$var(darkmode) ? $var(gray-800) : $var(gray-900)}]    widgetDefault
        option add *Scale.foreground          $var(body-color)                                              widgetDefault
        option add *Scale.borderWidth         0                                                             widgetDefault
        option add *Scale.sliderRelief        flat                                                          widgetDefault
        option add *Scale.highlightThickness  0                                                             widgetDefault
        option add *Scale.font                $comp_font                                                    widgetDefault

        # Scrollbar (classic): legacy widget; ttk::scrollbar is preferred but
        # cover it for completeness. Mirrors the SVG-driven ttk thumb steps.
        option add *Scrollbar.troughColor      [expr {$var(darkmode) ? $var(gray-300) : $var(gray-200)}]   widgetDefault
        option add *Scrollbar.background       [expr {$var(darkmode) ? $var(gray-600) : $var(gray-500)}]   widgetDefault
        option add *Scrollbar.activeBackground [expr {$var(darkmode) ? $var(gray-700) : $var(gray-600)}]   widgetDefault
        option add *Scrollbar.borderWidth      0                                                            widgetDefault
        option add *Scrollbar.highlightThickness 0                                                          widgetDefault

        # Menubutton (classic): matches TMenubutton.
        option add *Menubutton.background         $var(gray-300)                       widgetDefault
        option add *Menubutton.foreground         $var(neutral-content-color-default)  widgetDefault
        option add *Menubutton.activeBackground   $var(gray-400)                       widgetDefault
        option add *Menubutton.activeForeground   $var(neutral-content-color-default)  widgetDefault
        option add *Menubutton.disabledForeground $var(disabled-content-color)         widgetDefault
        option add *Menubutton.borderWidth        0                                    widgetDefault
        option add *Menubutton.relief             flat                                 widgetDefault
        option add *Menubutton.highlightThickness 0                                    widgetDefault
        option add *Menubutton.padX               $var(spacing-200)                    widgetDefault
        option add *Menubutton.padY               $var(spacing-100)                    widgetDefault
        option add *Menubutton.font               $comp_font                           widgetDefault

        # Canvas: drawing surface = canvas layer.
        option add *Canvas.background            $var(background-base-color) widgetDefault
        option add *Canvas.borderWidth           0                           widgetDefault
        option add *Canvas.highlightThickness    0                           widgetDefault

        # Text: long-form content on the canvas.
        option add *Text.background              $var(background-base-color)                                  widgetDefault
        option add *Text.foreground              $var(body-color)                                             widgetDefault
        option add *Text.insertBackground        $var(body-color)                                             widgetDefault
        option add *Text.selectBackground        $sel_bg                                                      widgetDefault
        option add *Text.selectForeground        $sel_fg                                                      widgetDefault
        option add *Text.relief                  flat                                                         widgetDefault
        option add *Text.borderWidth             0                                                            widgetDefault
        option add *Text.highlightThickness      0                                                            widgetDefault
        option add *Text.font                    $comp_font                                                   widgetDefault

        # Menu: popover surface (background-layer-2-color, gray border) per
        # spectrum-css popover. Hover uses a subtle gray, not the OS highlight.
        option add *Menu.background              $var(background-layer-2-color)        widgetDefault
        option add *Menu.foreground              $var(neutral-content-color-default)   widgetDefault
        option add *Menu.activeBackground        $hover_bg                             widgetDefault
        option add *Menu.activeForeground        $var(neutral-content-color-default)   widgetDefault
        option add *Menu.selectColor             $var(accent-background-color-default) widgetDefault
        option add *Menu.disabledForeground      $var(disabled-content-color)          widgetDefault
        option add *Menu.activeBorderWidth       0                                     widgetDefault
        option add *Menu.borderWidth             0                                     widgetDefault
        option add *Menu.relief                  flat                                  widgetDefault
        option add *Menu.font                    $comp_font                            widgetDefault

        # Combobox popup listbox: popover surface (matches Menu).
        option add *TCombobox*Listbox.background        $var(background-layer-2-color)         widgetDefault
        option add *TCombobox*Listbox.foreground        $var(neutral-content-color-default)    widgetDefault
        option add *TCombobox*Listbox.selectBackground  $sel_bg                                widgetDefault
        option add *TCombobox*Listbox.selectForeground  $sel_fg                                widgetDefault
        option add *TCombobox*Listbox.borderWidth       0                                      widgetDefault
        option add *TCombobox*Listbox.font              $field_font                            widgetDefault

        # Catch-all for any classic widget we didn't enumerate.
        option add *font $comp_font widgetDefault

        # Re-apply options to existing widget instances. New widgets pick up
        # the option db at creation; existing ones need an explicit reconfigure.
        # The root window . always gets refreshed regardless of class — Tk
        # gives it a class derived from the application name, which is never
        # in our enumerated list.
        set classic_classes {
            Toplevel Frame Label Message Button
            Checkbutton Radiobutton
            Entry Spinbox Listbox
            Scale Scrollbar
            Menubutton Canvas Text Menu
        }
        set widgets [list .]
        while {$widgets ne ""} {
            set widgets [lassign $widgets current]
            if {$current eq "." || [winfo class $current] in $classic_classes} {
                my RefreshWidget $current
            }
            lappend widgets {*}[lreverse [winfo children $current]]
        }
    }

    method RefreshWidget {widget} {
        # Re-pull theme defaults from the option database onto an existing
        # widget. The list is the union of options touched by tk_setPalette
        # and our class-specific option add calls. catch is intentional:
        # any option that doesn't apply to the widget's class no-ops.
        set options {
            activeBackground activeBorderWidth activeForeground activeRelief
            background borderWidth buttonBackground
            disabledBackground disabledForeground
            font foreground
            highlightBackground highlightColor highlightThickness
            insertBackground insertBorderWidth insertWidth
            padX padY
            relief
            selectBackground selectBorderWidth selectColor selectForeground
            sliderRelief
            troughColor
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
