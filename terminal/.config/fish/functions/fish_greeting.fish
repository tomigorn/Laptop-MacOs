function fish_greeting
    fastfetch
    # Show the terminal-setup version (read live from the repo's SETUP_VERSION
    # file, so a bump appears in any new shell without reloading this function).
    # The file sits at terminal/SETUP_VERSION, three levels up from this function.
    set -l self (realpath (status -f) 2>/dev/null)
    if test -n "$self"
        set -l vfile (dirname $self)/../../../SETUP_VERSION
        if test -f $vfile
            echo ""
            echo -n "  "                              # indent (outside the highlight)
            set_color -b 1864ab ffffff                # highlighted badge: white on deep blue (hex, theme-proof)
            echo -n "  Tomigorn's macOS Terminal Setup — v"(cat $vfile | string trim)"  "
            set_color normal
            echo ""
        end
    end
    # Nudge only; the check itself never runs here.
    if command -q mac-outdated
        set -l stamp ~/.local/state/mac-outdated/last-check
        set -l last
        test -f $stamp; and set last (string trim < $stamp)
        if not string match -qr '^[0-9]+$' -- "$last"
            echo "  software not checked yet: mac-outdated"
        else
            set -l age (math (date +%s) - $last)
            test $age -gt 604800; and echo "  software not checked for "(math --scale=0 $age / 86400)" days: mac-outdated"
        end
    end
end
